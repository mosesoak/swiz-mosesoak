package org.swizframework.utils.services
{
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.LoaderContext;

	public interface IURLRequestHelper
	{
		function executeURLRequest( request:URLRequest, resultHandler:Function, faultHandler:Function = null,
									progressHandler:Function = null, httpStatusHandler:Function = null,
									eventArgs:Array = null, useLoader:Boolean = false, 
									context:LoaderContext = null, urlLoaderDataFormat:String = null,
									timeoutSeconds:uint=10, tries:uint=1, returnURLRequest:Boolean=false ): SwizURLRequest;
	}
}