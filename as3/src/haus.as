package
{
	
   	import Texmap;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.text.TextField;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.setInterval;
	
	import org.osmf.layout.AbsoluteLayoutFacet;
		
		
	[SWF(width="240", height="140", frameRate="15", backgroundColor="#FFFFFF")]
	public class haus extends Sprite {
		private var tex		:Texmap;
		private var cam		:Camera;
		private var video	:Video;
		private var now		:BitmapData;
		private var rez		:BitmapData;
	//	private var out		:BitmapData;
		private var diff	:BitmapData;
		private var prev	:BitmapData;
		private var label	:TextField;
		private var label1	:TextField;
		private var label2	:TextField;
		private var myInt	:Number;
		private var frame	:Number 	= 0;
		private var bthresh	:Number 	= 190;
		private var ethresh	:Number 	= 10;
		private var doGrab	:Boolean 	= false;
		private var doRec	:Boolean 	= false;
		private var doJs	:Boolean 	= true;
		private var time	:Number		= 0;
		private var fps		:Number		= 10;

		private var rec	:Array 	= new Array();
			
		public function haus () {
				
			//stage.scaleMode = StageScaleMode.NO_SCALE;

			tex = new Texmap( 64 );

			label = new TextField();
			label.y = 80;
			label.width = 640;
			label1 = new TextField();
			label1.y = 95;	
			label1.width = 640;
			label2 = new TextField();
			label2.y = 110;	
			label2.width = 640;
			label.textColor = 
			label1.textColor = 
			label2.textColor = 0xcccccc;
				
			cam = Camera.getCamera();
			//cam.setMode(camW, camH, camFPS);			
			if (cam == null || cam.width==-1) {
				label.text = "NO WEBCAM FOUND";
			} else {
				video = new Video(cam.width, cam.height);
				video.attachCamera(cam);
				
				now = new BitmapData(video.width, video.height);
				rez = new BitmapData(64,64);
				//out = new BitmapData(64,64);
				diff = new BitmapData(64,64);
				prev = new BitmapData(64,64);
				
				var rt:DisplayObject = addChild(new Bitmap(rez));
				
				var previous:DisplayObject = addChild(new Bitmap(prev));
				previous.x = 80;
				
				var diffBitmap:DisplayObject = addChild(new Bitmap(diff));
				diffBitmap.x = 160;
											
				stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressedDown);
				myInt = setInterval(render, 50);
			}
			addChild(label);
			addChild(label1);
			addChild(label2);
		}


				
		private function keyPressedDown(event:KeyboardEvent):void {
			var key:uint = event.keyCode;
			switch (key) {
				case Keyboard.BACKSPACE :
					rec.pop();
					break;
				case Keyboard.F6 :
					doJs = !doJs;
					break;
				case Keyboard.DELETE :
					rec = new Array();
					break;
				case Keyboard.ENTER :
					doRec=true;
					break;
				case Keyboard.SPACE :
					if ( tex.back != null )
					{
						tex.back = null;
					}
					else
					{
						tex.back = new Array( tex.size * tex.size );
						doGrab = true;
					}
					break;
				case Keyboard.DOWN :
					bthresh -=1;
					break;
				case Keyboard.UP :
					bthresh +=1;
					break;
				case Keyboard.LEFT :
					ethresh --;
					break;
				case Keyboard.RIGHT :
					ethresh ++;
					break;
			}
		}
			
		
		private function clearTex ( bm:BitmapData ):void 
		{				
			for ( var j:int=0; j<64; j++ )
			{
				for ( var i:int=0; i<64; i++ )
				{
					bm.setPixel(i,j,0);
				}
			}
		}
		private function renderTex ( bm:BitmapData, tx:Array, color:int=255, off:int=-3 ):void 
		{				
			for ( var j:int=0,k:int=0; j<64; j++ )
			{
				for ( var i:int=0; i<64; i++,k++ )
				{
					if ( tx[k] > off )
						bm.setPixel(i,j,(color*tx[k]));
				}
			}
		}
		private function render ():void {
			var time1:Date = new Date();
		
			if (!cam.currentFPS) return;
			

			now.draw(video);
			var scaleMatrix:Matrix=new Matrix();
			scaleMatrix.scale(64/now.width,64/now.height);
			rez.draw(now,scaleMatrix);
			
			var b0:ByteArray = rez.getPixels(new Rectangle(0,0,64,64));
			var tr:int = bthresh*bthresh * (tex.back==null ? 2 : 0.5);
			tex.sample( b0, 64,64, tr, doGrab );
			doGrab = false;

			renderTex( prev, tex.bin );
			
			tex.outline(ethresh);

			if ( doRec ) 
			{
				rec.push(tex.clone());
			}
			doRec = false;
			
			//clearTex(diff);
			renderTex( diff, tex.bin, 65793 );
			
			// if something recorded, draw it,
			// find the one with the least diff to the current pointset
			var d:int = 1000000;
			var di:int = -1;
			for ( var i:int=0; i<rec.length; i++ )
			{
				renderTex( diff, rec[i], (0x331254 + 1211413*i)%0xfffff, 1 );
				var dm:int = tex.distanceTo( rec[i] );
				if ( dm < d )
					d = dm, di=i;
			}			
			if ( d>80 )
				d=di=-1;
			
			// calc js function
			if ( doJs )
			{
				try 
				{
					ExternalInterface.call("gestureFound",di);
				} 
				catch(e:Error) 
				{
					label1.text = e.toString();
					return;
				}
			}

			// calc fps
			var time2:Date = new Date();
			var s1:Number = time1.time; 
			var s2:Number = time2.time; 
			time += (s2-s1);
			frame ++;
			if ( frame %10 == 0 )
			{
				fps  = 1.0 / ( time / 1000.0 );
				fps  = int(100*fps)/100;
				time = 0;
			}

			label.text  = "thresh\t" + bthresh    + "\t\tedge  \t" + ethresh;
			label1.text = "recs  \t" + rec.length + "\t\tfound \t" + ((di<0)?"-" : di + " /" + d);
			label2.text = "bg    \t" + (tex.back!=null?"on":"off")+"\t\tfps   \t" + fps;
		}
	}
}