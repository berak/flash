package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.text.TextField;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.setInterval;
	
	import org.osmf.layout.AbsoluteLayoutFacet;
	import org.osmf.net.dynamicstreaming.INetStreamMetrics;
	
	
	[SWF(width="320", height="240", frameRate="15", backgroundColor="#aaaaaa")]
	public class ean2 extends Sprite {
		private var cam		:Camera;
		private var video	:Video;
		private var now		:BitmapData;
		private var label	:TextField;
		private var label1	:TextField;
		private var label2	:TextField;
		private var line	:Array;
		private var code	:Array;
		private var myInt	:Number;
		private var frame	:Number 	= 0;
		private var fps		:Number		= 10;
		
		private var xbits	:String = "";
		private var lean	:String = "";

		private var sean	:String = "";
		private var doJs	:Boolean 	= true;
		private var doItl	:Boolean 	= true;
		private var doGepir	:Boolean 	= true;
		private var time	:Number		= 0;
		//
		// normally, you'd only need 4 bits to encode a single digit [0..9],  
		// nifty 7-bit patterns are chosen here to ensure 2 bit error detection!
		//
		private var lh8:Array		= [ "0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011" ];
		private var rh8:Array 		= [ "1110010", "1100110", "1101100", "1000010", "1011100", "1001110", "1010000", "1000100", "1001000", "1110100" ];
		private var lh_odd13:Array  = [ "0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011" ];
		private var lh_even13:Array = [ "0100111", "0110011", "0011011", "0100001", "0011101", "0111001", "0000101", "0010001", "0001001", "0010111" ];
		private var rh_all13:Array  = [ "1110010", "1100110", "1101100", "1000010", "1011100", "1001110", "1010000", "1000100", "1001000", "1110100" ];	
		private var parity13:Array  = [ "111111",  "110100",  "110010",  "110001",  "101100",  "100110",  "100011",  "101010",  "101001",  "100101"  ];
		// debug counters:
		private var cnt:Array = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
		
		
		public function ean2 () {
			//test();
			
			//stage.scaleMode = StageScaleMode.NO_SCALE;
			label = new TextField();
			label.y = 30;
			label.width = 640;
			label1 = new TextField();
			label1.y = 45;	
			label1.width = 640;
			label2 = new TextField();
			label2.y = 60;	
			label2.width = 640;
			label.textColor = 
			label1.textColor = 
			label2.textColor = 0xcccccc;
		
			cam = Camera.getCamera();
			cam.setMode(320,240, 15);			
			if (cam == null || cam.width==-1) {
				label.text = "NO WEBCAM FOUND";
			} else {
				video = new Video(cam.width, cam.height);
				video.attachCamera(cam);
				now = new BitmapData(video.width, video.height);
				addChild(new Bitmap(now));
				//stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressedDown);
				myInt = setInterval(render, 50);
				line = new Array(video.width);
				code = new Array(64);
			}
			addChild(label);
			addChild(label1);
			addChild(label2);
		}
		private function dec( bits:String, off:int, table:Array, howMany:int ):int
		{
			for( var i:int=0; i<10; i++  )
			{
				if ( bits.substr(off,howMany) == table[i] )
					return i;
			}
			return -1;
		}
		private function setEan( count:int ): void
		{
			sean="";			
			for ( var i:int=0; i<count; i++ )
				sean += code[i];
		}
		private function checkMarker( bits:String, end:int ):int
		{
			var cen:int = end / 2;
			
			// check guards:
			if ( bits.charAt(0)     != '1' ) return 1; //"!L";
			if ( bits.charAt(1)     != '0' ) return 1; //"!L";
			if ( bits.charAt(2)     != '1' ) return 1; //"!L";
			
			if ( bits.charAt(cen-2) != '0' ) return 2; //"!C";
			if ( bits.charAt(cen-1) != '1' ) return 2; //"!C";
			if ( bits.charAt(cen  ) != '0' ) return 2; //"!C";
			if ( bits.charAt(cen+1) != '1' ) return 2; //"!C";
			if ( bits.charAt(cen+2) != '0' ) return 2; //"!C";
			
			if ( bits.charAt(end-2) != '1' ) return 3; //"!E";
			if ( bits.charAt(end-1) != '0' ) return 3; //"!E";
			if ( bits.charAt(end  ) != '1' ) return 3; //"!E";
			
			return 0; // ok.
		}			
		private function checksum( sum:int ) : int
		{
			var div:int = sum / 10;
			var rem:int = sum - div * 10;
			return ( rem ? 10 - rem : 0 );
		}
		private function checksum8( v:Array ) : int
		{
			return checksum(
				  (v[1]+v[3]+v[5])				// odd
				+ (v[0]+v[2]+v[4]+v[6]) * 3 );	// even
		}
		private function checksum13( v:Array ) : int
		{
			return checksum(
				(v[1]+v[3]+v[5]+v[7]+v[9]+v[11]) * 3	// odd
			  + (v[0]+v[2]+v[4]+v[6]+v[8]+v[10]) );		// even
		}
		private function decode8( bits:String ):int
		{
			var len:int = 67;
			var end:int = len-1;
			var ok:int = checkMarker( bits, end );
			if ( ok != 0 )
				return 5;
			//
			// decode the left 4 digits.
			//
			var k:int=0;
			var i:int=0;
			var z:int=0;
			var cen:int = len / 2;
			for ( i=3; i<cen-2; i+=7,k++ )
			{
				// check for odd:
				z = dec( bits, i, lh8, 7 );
				if ( z == -1 )
				{
					return 6; //"!D";
				}
				code[k] = z;
			}
			
			//
			// decode digits 4-8 including the checksum)
			//
			for ( i=cen+3; i<end-2; i+=7,k++ )
			{
				z = dec( bits, i, rh8, 7 );
				if ( z == -1 )
				{
					return 7; //"!D";
				}
				code[k] = z;
			}
			
			// 
			// check again:
			//
			var c:int = checksum8( code );
			if ( code[7] != c )
			{
				//printf("!!    %s   checksum err : %d %d\n", code, c2i(code[7]),c );
				return 8;
			}
						
			setEan(8);			
			return 0; // ok!!!	
		}
		private function decode13( bits:String ):int
		{
			var len:int = 95;
			var end:int = len-1;
			var cen:int = len / 2;
			
			var ok:int = checkMarker( bits, end );
			if ( ok != 0 )
				return 5;
			
			//
			// decode the left 6 digits(1-7).
			// they were encoded odd or even according to the parity digit(0),
			// store, which coding it was to reconstruct parity ( the first digit ) later.
			//
			var par:String = "";
			var k:int=0;
			var i:int=0;
			var z:int=0;
			for ( i=3; i<cen-2; i+=7,k++ )
			{
				// check for odd:
				z = dec( bits, i, lh_odd13, 7 );
				if ( z != -1 )
				{
					code[k+1] = z;
					par += '1';
					continue;
				}
				// check for even:
				z = dec( bits, i, lh_even13, 7 );
				if ( z != -1 )
				{
					code[k+1] = z;
					par += '0';
					continue;
				}
				// decode error !
				return 6; //"!D";
			}
			
			//
			// decode parity( first digit ) from odd/even info collected before:
			//
			code[0] = dec( par, 0, parity13, 6 );

			//
			// decode digits 7-13 (including the checksum)
			//
			for ( i=cen+3; i<end-2; i+=7,k++ )
			{
				z = dec( bits, i, rh_all13, 7 );
				if ( z == -1 )
				{
					return 7;
				}
				code[k+1] = z;
			}
			
			// 
			// check again:
			//
			var c:int = checksum13( code );
			if ( code[12] != c )
			{
				// kinda hard to let go here (after all that work!), but the result was wrong!
				return 8;
			}
			
			setEan(13);			
			return 0; // ok!!!	
		}
		//
		// i ain't quiet, everybody else is too loud.
		//
		private function quietZone(start:int,stop:int,step:int, mean:int):Point 
		{
			var res:Point = new Point;
			var tmp:Point = new Point;
			for ( var i:int=start; (step>0&&i<stop)||(step<0&&i>stop); i+=step )
			{
				if ( line[i]> mean )
				{
					tmp.x = i;
					tmp.y ++;
				}
				else
				{
					if ( res.y < tmp.y )
						res.x = tmp.x, res.y=tmp.y;
					tmp.x=0;
					tmp.y=0;
				}
			}
			if ( res.y < tmp.y )
				res = tmp;
			return res;
		}
		private function sampleLine(y:int):int 
		{
			// grayscale
			var mean:Number = 0; 
			var i:int = 0; 
			var x:int = 0; 
			var w:int = video.width; 
			var dr:int, dg:int, db:int;
			for ( x=0; x<w; x++ )
			{
				var p:uint = now.getPixel(x,y);
				dr = ((p    )&0xff);
				dg = ((p>> 8)&0xff);
				db = ((p>>16)&0xff);
				line[x] = (dr>>2) + (dg>>1) + (db>>2);
				mean += line[x]; 
			}
			mean /= w;
			
			// binaize:(NO, it actually works better without!!)
			for ( x=0; x<w; x++ )
			{
				//line[x] = ( (line[x] > mean) ? 255 : 0 ); 
				
				// draw (inverse) scanline
				now.setPixel(x,y,  ((line[x]> mean)?0x00ff00:0));
				now.setPixel(x,y+1,((line[x]> mean)?0x00ff00:0));
			}
			
			// find quiet zones:
			var  sl:Point = quietZone( 0,   w/2,  1, mean );
			var  sr:Point = quietZone( w-1, w/2, -1, mean );

			// draw them:
			for ( x=0; x<sl.x; x++ )
				now.setPixel(x,y,  0xff0000),
				now.setPixel(x,y+1,0xff0000);
			for ( x=sr.x; x<w; x++ )
				now.setPixel(x,y,  0xff0000),
				now.setPixel(x,y+1,0xff0000);
			
			
			var distance:int = sr.x - sl.x;
			if ( distance < 58 )
				return 1;
			
			// try to sample a square wave from the grayscale data
			// between the quiet zones,
			// start at first black pixel
			var last_state:Boolean = true;
			var pt:Array = new Array( ( distance ) * 2 ); // pos,length, pos,length, ..
			var ptSize:int = 0;// numpoints*2
			for( i = sl.x+1; i<sr.x; i++  )
			{
				// todo : check for local minima > mean , maxima < mean
				
				var state:Boolean = (line[i] < mean);
				
				// toggle state:
				if ( state != last_state )
				{
					pt[ptSize++] = i;
					pt[ptSize++] = 1;
					last_state = state;
					continue;
				}
				
				// state unchanged, increase length of current section
				pt[ptSize+1] ++; 
			}

			//
			// for ean13 it's 95 bits and 58 state toggles, 
			// for ean8  it's 67 bits and 42 state toggles. 
			//
			var siz:Number = distance;
			if ( ptSize == 58*2 )
			{
				siz /= 95.0; // ean13
			}
			else
			if ( ptSize == 42*2 )
			{
				siz /= 67.0; // ean8
			}
			else
				return 2;
			
			// scale pattern down to 1 pixel per bit:
			var sum:int = 0;
			var last:Number = (sl.x+1);
			var xa:Array = new Array(ptSize/2);
			for( i=0; i<ptSize; i+=2  )
			{
				var d:Number = pt[i] - last;
				last = pt[i];
				d = int( 0.5 + d/siz ); 
				sum += d;
				pt[i+1] = d;		// now holds bit count
			}
			if ( sum > 95 )
				return 3;
			
			// make bitstring:
			var bit:Boolean = true;
			var count:int = 0; 
			var bits:String = "";
			for( i=0; i<ptSize; i+=2  )
			{
				for( var j:int=0; j<pt[i+1]; j++ )
				{
					bits += ( bit ? '1' : '0' );
					if ( bits.length > 95 )
					{
						return 4;
					}
				}
				bit = ! bit;
			}
			bits += '1';
			xbits = bits;
			if ( bits.length == 67 )
				return decode8( bits );
			if ( bits.length == 95 )
				return decode13( bits );
			return 4;
		}
		
		
		private function render ():void {
	//		var time1:Date = new Date();
			
			if (!cam.currentFPS) return;
					
			now.draw(video);
			var w:int = video.width;
			var h:int = video.height;

			// debug counters for the bailout stages		
			if ( frame % 100 == 0 )
				cnt[0]=cnt[1]=cnt[2]=cnt[3]=cnt[4]=cnt[5]=cnt[6]=cnt[7]=cnt[8]=cnt[9]=0;
			
			// sample horizontal scanlines
			var step:int =8;
			var count:int=10;
			for ( var y:int = (h-count*step) / 2; y < (h+count*step) / 2; y += step )
			{
				var res:int = sampleLine(y);
				cnt[res]++;
				if ( res == 0 )
					startJob();
			}
			
/*			// calc fps
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
*/			
			//label.text = xbits.length + "\t" + xbits;
			//label1.text = "cnz   \t" + cnt[4] + "\t" + cnt[5] + "\t" + cnt[6] + "\t" + cnt[7] + "\t" + cnt[8]+"\t:\t" + cnt[0];
			//label.text = "fps   \t" + fps + "\t\t" + sean ;
			//label.text = "upc" + sean.length + "\t" + sean ;
		}
		
		
		private function callJS( fun:String, html:String ):void 
		{
			try 
			{
				ExternalInterface.call(fun, html  );
			} 
			catch(er:Error) 
			{
				label1.text = er.toString();
				return;
			}
		}
		
		
		private function startJob():void
		{
			// only shoot once, when we got a new ean
			if ( lean == sean )
				return;
			lean = sean;
			
			label.text = "ean" + sean.length + "\t" + sean ;
		
			var url:String  = 'http://p4p4.p4.ohost.de/php/ean.php';
			var upcs:String = (sean.length==13 ? sean : "00000" + sean);

			callJS("setText", "waiting for info on " + sean );
			rpcStart( url + '?ean='   + upcs , this.onLoadUpc );
			rpcStart( url + '?itl='   + sean , this.onLoadUpc );
			rpcStart( url + '?chk='   + sean , this.onLoadUpc );
			if ( sean.length == 13 )
			{
				rpcStart( url + '?amaz='  + sean , this.onLoadUpc );
				rpcStart( url + '?brain=' + sean , this.onLoadUpc );
				if ( 0 > sean.indexOf("978") )
					rpcStart( url + '?gepir=' + sean , this.onLoadUpc );
			}
		}
		
		
		private function rpcStart(url:String, listener:Function):void
		{
			try 
			{
				var request:URLRequest = new URLRequest(url);
				var response:URLLoader = new URLLoader();
				response.addEventListener(Event.COMPLETE, listener);			
				response.load(request);
			}
			catch(e:Error) 
			{
				label1.text = e.toString();
			}
		}

		
		private function onLoadUpc(e:Event):void
		{
			callJS("addText", e.target.data );
			label.text = "";
		}		
		
/*
		//
		// now there's a couple xml tools here, but they're all #@*Q!!
		//
		public function extract( html:String, from:String, to:String, off:int):String 
		{
			var i:int=html.indexOf(from,off);
			if ( i==-1 ) return null;
			i += from.length;
			var j:int=html.indexOf(to,i);
			if ( j==-1 ) return null;
			return html.substr(i,j-i);
		}

		
		private function onLoadGepir(e:Event):void
		{
			var table:String  = extract( e.target.data, "<tr class=\"evenRow\">", "</tr>", 0);
			callJS("addText", table );
		}
		private function onLoadIsbn(e:Event):void
		{
			var o:String = "";
			var html:String = e.target.data;
			if ( html.indexOf("BookList total_results=\"0\"") == -1 )
			{
				var title:String  = extract(html,"<Title>","</Title>",0);
				var publ:String   = extract(html,"PublisherText publisher_id=\"","\">",0);
				var author:String = extract(html,"<AuthorsText>","</AuthorsText>",0);
				var sum:String    = extract(html,"<Summary>","</Summary>",0);
				o = sean+ "<br>" + title+ "<br>" +author+ "<br>" +publ+ "<br>" +sum+ "<br>";
			}
			else
			{
				o = "sorry, no entry found at isbndb.com<br>";
			}
			callJS("addText", o );
		}
		private function onLoadUpc(e:Event):void
		{
			var o:String = "";
			var html:String = e.target.data;
			var stat:String = extract(html,"status</name><value><string>","</string>",0);
			var mess:String = extract(html,"message</name><value><string>","</string>",0);
			
			if ( stat == "success" )
			{
				if ( mess == "Database entry found" )
				{
					var upc:String  = extract(html,"ean</name><value><string>","</string>",0);
					var desc:String = extract(html,"description</name><value><string>","</string>",0);
					var size:String = extract(html,"size</name><value><string>","</string>",0);
					var orig:String = extract(html,"issuerCountry</name><value><string>","</string>",0);
					o = upc + "<br>" + desc + "<br>" +size +  "<br>" + orig;
					callJS("setText", o );
				}
				else
				{
					callJS("upcinfoUpload", sean );
				}
			}
			else
			{
				callJS( "setText", mess );
			}			
		}

		private function onLoadItl(e:Event):void
		{
			var html:String = e.target.data;
			var item:String = extract(html,"target=\"_blank\" rel=\"nofollow\">","</a>",0);
			var prod:String = extract(html,"<strong>Product Details:</strong>","<div class=\"res_row\">",0);
			var o:String = item + "<br>" + prod + "<br>";
			callJS("addText", o );
		}
*/	}
}
