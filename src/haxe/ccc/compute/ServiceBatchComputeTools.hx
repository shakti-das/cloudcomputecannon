package ccc.compute;

import ccc.compute.Definitions;
import ccc.storage.ServiceStorage;

import haxe.Json;

import js.Node;
import js.node.stream.Readable;
import js.node.Http;
import js.node.http.*;
import js.npm.Streamifier;

import promhx.Promise;

import util.DockerRegistryTools;
import util.DockerTools;

class ServiceBatchComputeTools
{
	// public static function pipeRedisLogs(redis :js.npm.RedisClient, ?streams :StdStreams)
	// {
	// 	if (streams == null) {
	// 		streams = {out:js.Node.process.stdout, err:js.Node.process.stderr};
	// 	}
	// 	var stdconvert :String->String = untyped __js__('require("cli-color").red.bgWhite');
	// 	var errconvert :String->String = untyped __js__('require("cli-color").red.bold.bgWhite');
	// 	var stdStream = services.RedisTools.createPublishStream(redis, ComputeQueue.REDIS_CHANNEL_LOG_INFO);
	// 	stdStream
	// 		.then(function(msg) {
	// 			streams.out.write(stdconvert('[REDIS] ' + msg + '\n'));
	// 		});
	// 	var errStream = services.RedisTools.createPublishStream(redis, ComputeQueue.REDIS_CHANNEL_LOG_ERROR);
	// 	errStream
	// 		.then(function(msg) {
	// 			streams.err.write(errconvert(js.npm.CliColor.red('[REDIS] ' + msg + '\n')));
	// 		});
	// }

	public static function checkRegistryForDockerUrl(url :DockerUrl) :Promise<DockerUrl>
	{
		if (url.registryhost != null) {
			return Promise.promise(url);
		} else {
			var host = ConnectionToolsRegistry.getRegistryAddress();
			return DockerRegistryTools.isImageIsRegistry(host, url.repository, url.tag)
				.then(function(isInRegistry) {
					if (isInRegistry) {
						url.registryhost = host;
						return url;
					} else {
						return url;
					}
				});
		}
	}
}