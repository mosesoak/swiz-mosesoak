/*
 * Copyright 2010 Swiz Framework Contributors
 * 
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License. You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 */

package org.swizframework.utils.services
{
	import flash.display.Loader;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.LoaderContext;
	import flash.utils.Timer;
	
	[ExcludeClass]
	
	/**
	 *
	 * DynamicUrlRequest can be used to wrap URLLoader calles.
	 * The faultHandler function will be used for IOErrors and SecurityErrors
	 * so you should type the argument Event and check/cast the specific type
	 * in the method body.
	 *
	 * When used implicitly from Swiz.executeUrlRequest or AbstractController.executeUrlRequest
	 * the generic fault handler will be applied if available. Otherwise in an error case
	 * the Swiz internal generic fault shows up.
	 *
	 */
	public class SwizURLRequest
	{
		public static const LOAD_TIMEOUT: String = "loadTimeout";
		
		protected var request:URLRequest;
		protected var resultHandler:Function;
		protected var faultHandler:Function;
		protected var progressHandler:Function;
		protected var httpStatusHandler:Function;
		protected var eventArgs:Array;
		protected var loader:Object;
		protected var dispatcher:IEventDispatcher;
		protected var tries:uint;
		protected var fails:int = 0;
		protected var useLoader:Boolean;
		protected var timer:Timer = timer;
		protected var context:LoaderContext;
		
		/**
		 *
		 * @param request
		 * @param resultHandler The resultHandler function must expect the an event. event.currentTarget.data should contain the result. Signature can be extended with additional handlerArgs
		 * @param faultHandler The faultHandler function will be called for IOErrors and SecurityErrors with the specific error event.
		 * @param progressHandler
		 * @param httpStatusHandler
		 * @param eventArgs The eventArgs will be applied to the signature of the resultHandler function.
		 * @param useLoader Pass true to use a Loader instead of URLLoader, for example to fetch image data.
		 * @param context Optional <code>LoaderContext</code> instance (when <code>useLoader</code> is true).
		 * @param urlLoaderDataFormat Optional <code>URLLoaderDataFormat</code> constant (when <code>useLoader</code> is false).
		 * @param timeoutSeconds After all load tries time out an <code>ErrorEvent</code> of type <code>SwizURLRequest.LOAD_TIMEOUT</code> is fired.
		 * 						 A setting of 4-6 seconds is recommended, but 0 (no timeout) is not since your delegate may be left hanging. 
		 * @param tries Total number of load tries (1 or higher). Example: <code>timeoutSeconds: 4, tries: 3</code> will time out in 12 seconds.
		 * 
		 */
		public function SwizURLRequest( request:URLRequest, resultHandler:Function, 
			faultHandler:Function = null, progressHandler:Function = null, 
			httpStatusHandler:Function = null, eventArgs:Array = null,
			useLoader:Boolean = false, context:LoaderContext = null, urlLoaderDataFormat:String = null,
			timeoutSeconds:uint=10, tries:uint=1, returnURLRequest:Boolean=false)
		{
			this.request = request;
			this.resultHandler = resultHandler;
			this.faultHandler = faultHandler;
			this.progressHandler = progressHandler;
			this.httpStatusHandler = httpStatusHandler;
			this.eventArgs = (eventArgs || new Array());
			if (returnURLRequest)
			{
				this.eventArgs.push(request);
			}
			this.useLoader = useLoader;
			this.context = context;
			
			if (timeoutSeconds)
			{
				this.tries = (tries || 1);
				timer = new Timer(timeoutSeconds * 1000, 1);
				timer.addEventListener(TimerEvent.TIMER_COMPLETE, load);
			}
			
			if (useLoader)
			{
				loader = new Loader();
				dispatcher = loader.contentLoaderInfo;
			}
			else
			{
				loader = new URLLoader();
				dispatcher = loader as IEventDispatcher;
				if (urlLoaderDataFormat)
				{
					loader.dataFormat = urlLoaderDataFormat;
				}
			}
			
			dispatcher.addEventListener( Event.COMPLETE, fire);
			dispatcher.addEventListener( IOErrorEvent.IO_ERROR, fire); 
			dispatcher.addEventListener( SecurityErrorEvent.SECURITY_ERROR, fire);
			if( progressHandler != null )
			{
				dispatcher.addEventListener( ProgressEvent.PROGRESS, fire);
			}
			
			if( httpStatusHandler != null )
			{
				dispatcher.addEventListener( HTTPStatusEvent.HTTP_STATUS, fire);
			}
			
			load();
		}
		
		public function cancel():void
		{
			if (timer)
			{
				timer.reset();
				timer.removeEventListener(TimerEvent.TIMER_COMPLETE, load);
				timer = null;
			}
			dispatcher.removeEventListener( Event.COMPLETE, fire);
			dispatcher.removeEventListener( IOErrorEvent.IO_ERROR, fire); 
			dispatcher.removeEventListener( SecurityErrorEvent.SECURITY_ERROR, fire);
			if( progressHandler != null )
			{
				dispatcher.removeEventListener( ProgressEvent.PROGRESS, fire);
			}
			
			if( httpStatusHandler != null )
			{
				dispatcher.removeEventListener( HTTPStatusEvent.HTTP_STATUS, fire);
			}
			try
			{
				loader.close();
			}
			catch (e:Error) {}
			context = null;
			eventArgs = null;
			loader = null;
			request = null;
		}
		
		protected function load(event:TimerEvent=null):void
		{
			if (event)
			{
				timer.reset();
				try
				{
					loader.close(); // Kill hanging HTTP stream before starting another
				}
				catch (e:Error) {}
				
				if (++fails == tries)
				{
					// Simulate a 404 on timeout since we may not get an actual browser status. (This might cause issues..)
					fire( new HTTPStatusEvent(HTTPStatusEvent.HTTP_STATUS, false, false, 404) );
					fire ( new ErrorEvent(LOAD_TIMEOUT, false, false, "Load timed out after " + tries + " attempt" + (tries == 1 ? "." : "s.")) );
					return;
				}
				else
				{
					trace("Retrying after timeout ('" + request.url + "')");
				}
			}
			
			try {
				if (useLoader)
				{
					loader.load( request, context );
				}
				else
				{
					loader.load( request );
				}
				if (timer)
				{
					timer.start();
				}
			}
			catch (error:Error)
			{
				fire ( new ErrorEvent(ErrorEvent.ERROR, false, false, error.toString()) );
			}
		}
		
		protected function fire(event:Event):void
		{
			if (timer)
			{
				timer.reset();
			}
			
			var handler:Function;
			var handlerName:String;
			var doCancel:Boolean;
			switch (event.type)
			{
				case Event.COMPLETE:
					handler = resultHandler;
					handlerName = "resultHandler";
					doCancel = true;
					break;
				case ProgressEvent.PROGRESS:
					handler = progressHandler;
					handlerName = "progressHandler";
					break;
				case HTTPStatusEvent.HTTP_STATUS:
					handler = httpStatusHandler;
					handlerName = "httpStatusHandler";
					break;
				default:
					handler = faultHandler;
					handlerName = "faultHandler";
					doCancel = true;
					break;
			}
			
			if (handler != null) {
				if ( eventArgs == null ) {
					handler( event );
				}
				else {
					try
					{
						handler.apply( null, new Array(event).concat(eventArgs) );
					}
					catch (e:ArgumentError)
					{
						// You will see an error here if a handler didn't have all the required argument inputs.
						// All handlers now receive the same set of arguments, in order to provide more information
						// about the delegated call during errors, status, and progress as well as completion.
						// The first argument will always be the original event fired by the loader, followed
						// by all eventArgs you passed in (which should appear as separate arguments in your handler),
						// followed by a final argument containing the original URLRequest you passed in if you 
						// set returnURLRequest to true.
						//
						// For handlers where you only want the event, you can write your signatures like this: 
						// protected function handler(event:Event, ...rest):void
						
						throw new Error(handlerName + " " + e);
					}
				}
			}
			
			if (doCancel)
			{
				cancel(); // Clears listeners, memory, and ensures there are no hanging HTTP calls. Leave this after handler is fired.
			}
		}
	}
}