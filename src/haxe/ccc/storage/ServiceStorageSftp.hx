package ccc.storage;

import js.node.Path;
import js.node.stream.Readable;
import js.node.stream.Writable;
import js.npm.TarGz;
import js.npm.Ssh;

import promhx.Promise;
import promhx.CallbackPromise;
import promhx.StreamPromises;
import promhx.deferred.DeferredPromise;

import ccc.storage.ServiceStorage;
import ccc.storage.StorageTools;

import util.SshTools;
import util.streams.StdStreams;

using promhx.PromiseTools;
using StringTools;

class ServiceStorageSftp
	extends ServiceStorageBase
{
	public static function fromInstance(instance :ccc.compute.Definitions.InstanceDefinition, ?rootPath :String = '')
	{
		var config :StorageDefinition = {
			type: StorageSourceType.Sftp,
			rootPath: rootPath,
			sshConfig: instance.ssh
		}
		return new ServiceStorageSftp().setConfig(config);
	}

	public function new()
	{
		super();
	}

	override public function setConfig(config :StorageDefinition)
	{
		Assert.notNull(config);
		Assert.notNull(config.sshConfig);
		Assert.notNull(config.sshConfig.host);
		Assert.that(config.sshConfig.host != '');
		return super.setConfig(config);
	}

	override public function appendToRootPath(path :String) :ServiceStorage
	{
		var config = Reflect.copy(_config);
		config.rootPath = getPath(path);
		return new ServiceStorageSftp()
			.setStreams(_streams)
			.setConfig(config);
	}

	override public function readFile(path :String) :Promise<IReadable>
	{
		path = getPath(path);
		return SshTools.readFile(_config.sshConfig, path);
	}

	override public function readDir(?path :String) :Promise<IReadable>
	{
		throw 'Not implemented';
		return null;
	}

	override public function makeDir(?path :String) :Promise<Bool>
	{
		path = getPath(path);
		return mkdirInternal(path);
	}

	function mkdirInternal(path :String) :Promise<Bool>
	{
		return __sshCommand('mkdir -p ' + path)
			.then(function(result :ExecResult) {
				if (result.code != 0 || result.stderr != null) {
					throw 'Error with "mkdir -p $path" on ${_config.sshConfig.host} result=$result';
				}
				return true;
			});
	}

	override public function writeFile(path :String, data :IReadable) :Promise<Bool>
	{
		path = getPath(path);
		var dir = Path.dirname(path);

		return Promise.promise(true)
			.pipe(function(_) {
				return mkdirInternal(dir);
			})
			.pipe(function(_) {
				return __getSftp();
			})
			.pipe(function(connections) {
				var sftp = connections.sftp;
				var promise = new DeferredPromise();
				var writeStream = sftp.createWriteStream(path);
				//Listen to the FINISH event of the writable stream
				//NOT the 'end' or 'close' event of the readable stream
				//http://stackoverflow.com/questions/13156243/event-associated-with-fs-createwritestream-in-node-js
				return StreamPromises.pipe(data, writeStream, [WritableEvent.Finish], 'ServiceStorageSftp.writeFile path=$path')
					.then(function(_) {
						connections.ssh.end();
						return true;
					});
			});
	}

	override public function getFileWritable(path :String) :Promise<IWritable>
	{
		path = getPath(path);
		var dir = Path.dirname(path);
		return Promise.promise(true)
			.pipe(function(_) {
				return mkdirInternal(dir);
			})
			.pipe(function(_) {
				return __getSftp();
			})
			.then(function(connections) {
				var sftp = connections.sftp;
				var writable = sftp.createWriteStream(path);

				writable.once(ReadableEvent.Close, function() {
					js.Node.setImmediate(function() {
						connections.ssh.end();
					});
				});
				return writable;
			});
	}

	override public function copyFile(source :String, target :String) :Promise<Bool>
	{
		Log.error('Not yet implemented');
		return Promise.promise(true);
	}

	override public function deleteDir(?path :String) :Promise<Bool>
	{
		path = getPath(path);

		return __sshCommand('rm -rf ' + path)
			.then(function(_) {
				return true;
			});
	}

	override public function deleteFile(path :String) :Promise<Bool>
	{
		return deleteDir(path);
	}

	override public function listDir(?path :String) :Promise<Array<String>>
	{
		var path = getPath(path);
		if (!path.endsWith('/')) {
			path += '/';
		}
		return __sshCommand('find $path -type f')
			.then(function(execResult) {
				if (execResult.stdout != null) {
					return execResult.stdout.trim().split('\n')
							.filter(function(s) return s != null && s.trim().length > 0)
							.map(function(s) return s.replace(path, ''));
				} else {
					return [];
				}
			});
	}

	override public function close()
	{
		_streams = null;
		_rootPath = null;
	}

	public function setStreams(val :StdStreams)
	{
		_streams = val;
		return this;
	}

	override public function toString()
	{
		return '[StorageSsh _rootPath=$_rootPath host=${_config.sshConfig.host}]';
	}

	function __getSsh() :Promise<SshClient>
	{
		return SshTools.getSsh(_config.sshConfig);
	}

	function __getSftp() :Promise<{ssh:SshClient, sftp:SFTPStream}>
	{
		return SshTools.getSftp(_config.sshConfig);
	}

	function __sshCommand(command :String) :Promise<ExecResult>
	{
		return SshTools.execute(_config.sshConfig, command);
	}

#if debug
	public
#end
	var _streams :StdStreams;
}