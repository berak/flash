package {
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.utils.setInterval;

	public class eyes extends Sprite 
	{		
		private var cam		:Camera;
		private var video	:Video;
		private var now		:BitmapData;
		private var out		:BitmapData;
		private var diff	:BitmapData;
		private var prev	:BitmapData;
		private var label	:TextField;
		private var myInt	:Number;
		private var camFPS	:Number 	= 15;
		private var camW	:Number 	= 250;
		private var camH	:Number 	= 190;
		private var motion	:Point;
		private var eye_l	:Bitmap;
		private var eye_r	:Bitmap;
		private var eye_lp	:Point;
		private var eye_rp	:Point;
		private var pe1		:DisplayObject; 
		private var pe2		:DisplayObject; 
		
		private var myLoader:Loader;;
		
		
		public function eyes () 
		{
			eye_lp = new Point( 60,60 );
			eye_rp = new Point( 260,60 );
			cam = Camera.getCamera();
			label = new TextField();
			label.x = 60;
			label.y = 80;
			label.width = 400;
			label.text = "NO WEBCAM";
			addChild(label);

			if (cam != null) 
			{
				label.text = "";
				video = new Video(cam.width, cam.height);
				video.attachCamera(cam);
				
				out = new BitmapData(video.width, video.height);
				diff = new BitmapData(video.width, video.height);
				prev = new BitmapData(video.width, video.height);
				
				//var p0 = addChild(video);
				//var p1 = addChild(new Bitmap(diff));
				//p1.x = video.width;			
				//var p2 = addChild(new Bitmap(out));
				//p2.y = video.height;
						
				myInt = setInterval(render, 2000/camFPS);
				motion = new Point(0,0);
			}
			myLoader = new Loader();
			myLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoaderReady);
			
			var fileRequest:URLRequest = new URLRequest("eye.png");
			myLoader.load(fileRequest);
		}
		
		public function onLoaderReady(e:Event):void 
		{  
			eye_l = e.target.content;
			pe1 = addChild(eye_l);
			pe1.width  = 200;
			pe1.height = 200;
			pe1.x = eye_lp.x;
			pe1.y = eye_lp.y;	
			eye_r = new Bitmap(eye_l.bitmapData);
			pe2 = addChild(eye_r);
			pe2.width  = 200;
			pe2.height = 200;
			pe2.x = eye_rp.x;
			pe2.y = eye_rp.y;	
		}		

		private function checkDiff ( bm:BitmapData, msize:int=9 ):int 
		{
			var tx:Array = new Array( msize*msize );
			var sx:int = bm.width / msize;
			var sy:int = bm.height / msize;
			for ( var k:int=0; k<msize*msize; k++ )
			{
				tx[ k ] = 0;
			}
			for ( var j:int=0; j<bm.height; j++ )
			{
				for ( var i:int=0; i<bm.width; i++ )
				{
					var p:uint = bm.getPixel(i,j);
					if ( p == 0xff0000 )
					{
						tx[ i/sx + msize*(j/sy) ] ++;
					}
				}
			}
			var biggest:int = 0;
			var id:int = -1;
			for ( var k:int=0; k<msize*msize; k++ )
			{
				if ( tx[ k ]> biggest )
				{
					id = k;
					biggest = tx[k];
				}
			}
			return id;
		}

		
		private function render ():void 
		{		
			if (!cam.currentFPS) return;
			
			diff.draw(video);
			diff.draw(prev,null,null,"difference");
			out.fillRect(new Rectangle(0,0,out.width,out.height),0xFF000000);
			var npix:int = out.threshold(diff, new Rectangle(0,0,diff.width,diff.height), new Point(0,0), ">", 0xFF222222, 0xFFFF0000);
			prev.draw(video);
			
			var mscale:int = 9;
			var d:int = checkDiff( out, mscale );
			if ( d != -1 )
			{
				var p:Point = new Point( (d % (mscale)) - mscale/2, (d / mscale) - mscale/2 );
				motion.x -= p.x/4;
				motion.y += p.y/4;
				//motion.x = p.x;
				//motion.y = p.y;
			}
			
			//label.text = "" + (int(motion.x*100)/100) + " " + (int(motion.y*100)/100) + "\t" + d + "\t" + npix;

			if ( Math.abs( motion.x ) > 0.1 )
				motion.x *= 0.9;
			else
				motion.x = 0;
			if ( Math.abs( motion.y ) > 0.1 )
				motion.y *= 0.9;
			else
				motion.y = 0;
			if ( pe1 != null && pe2 != null )
			{
				pe1.x = eye_lp.x + motion.x * 15;
				pe1.y = eye_lp.y + motion.y * 15;
				pe2.x = eye_rp.x + motion.x * 15;
				pe2.y = eye_rp.y + motion.y * 15;
			}
		}
	}
}