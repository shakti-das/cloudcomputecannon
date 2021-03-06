package promhx;

import js.node.buffer.Buffer;
import js.node.stream.Readable;
import js.node.stream.Writable;

import promhx.Promise;
import promhx.Deferred;
import promhx.Stream;
import promhx.deferred.DeferredPromise;

using Lambda;

class StreamPromises
{
	public static function pipe(readable :IReadable, writable :IWritable, ?endEvents :Array<String>, ?errorContext :Dynamic) :Promise<Bool>
	{
		var deferred = new promhx.deferred.DeferredPromise();
		var isResolvedOrRejected = false;
		var disableErrorLogs = false;
		var resolve = function() {
			if (!isResolvedOrRejected) {
				isResolvedOrRejected = true;
				// trace('resolving $errorContext');
				deferred.resolve(true);
			} else {
				if (!disableErrorLogs) {
					Log.error('Getting more than one call to resolve pipe promise');
				}
			}
		}
		var reject = function(e) {
			if (!isResolvedOrRejected) {
				isResolvedOrRejected = true;
				// trace('rejecting $errorContext ${Std.string(e)}');
				deferred.boundPromise.reject(e);
			} else {
				if (!disableErrorLogs) {
					Log.error({'message':'THIS IS OUT OF THE PROMISE CHAIN StreamPromises.pipe readable error', error:e, errorContext:errorContext});
				}
			}
		}
		if (endEvents != null) {
			for (endEvent in endEvents) {
				writable.once(endEvent, resolve);
			}
		}
		if (endEvents == null || !endEvents.has(WritableEvent.Finish)) {
			writable.on(WritableEvent.Finish, resolve);
		}

		readable.on('response', function(response :{statusCode:Int}) {
			if (Reflect.hasField(response, 'statusCode')) {
				if (response.statusCode >= 400) {
					reject(ErrorTools.create({statusCode:response.statusCode, errorContext:errorContext}));
					disableErrorLogs = true;
					try {
						readable.unpipe(writable);
					} catch (_ :Dynamic) {
						try {
							untyped readable.end();
						} catch (_ :Dynamic) {
							//
						}
					}
					// writable.end();
				}
			}
		});

		//Listen to both read and write errors.
		writable.on(WritableEvent.Error, function(err) {
			Log.error({'message':'StreamPromises.pipe writable error', error:err, errorContext:errorContext});
			reject(err);
			writable.end();
		});
		readable.on(ReadableEvent.Error, function(err) {
			Log.error({'message':'StreamPromises.pipe readable error', error:err, errorContext:errorContext});
			reject(err);
			writable.end();
		});

		readable.pipe(writable);

		return deferred.boundPromise;
	}

	public static function streamToString(stream :IReadable) :Promise<String>
	{
		var promise = new DeferredPromise();
		var buffer :Buffer = null;
		stream.on(ReadableEvent.Error, function(err) {
			if (!promise.isResolved()) {
				promise.boundPromise.reject(err);
			} else {
				Log.error(err);
			}
		});
		stream.once(ReadableEvent.End, function() {
			if (!promise.isResolved()) {
				promise.resolve(buffer != null ? buffer.toString() : null);
			}
		});
		stream.on(ReadableEvent.Data, function(chunk :Buffer) {
			if (buffer == null) {
				buffer = chunk;
			} else {
				buffer = Buffer.concat([buffer, chunk]);
			}
		});
		return promise.boundPromise;
	}
}