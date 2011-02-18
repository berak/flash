package
{
	import flash.utils.ByteArray;

	
	public class Texmap
	{
		public var bin:Array = null;
		public var back:Array = null;
		public var pta:Array = null;
		public var ptb:Array = null;
		public var size:int = 0;
		public var sizeA:int = 0;
		public var sizeB:int = 0;
		public var sizeE:int = 0;
		
		public function Texmap(s:int)
		{
			size=s;
			if (s>0)
			{
				bin = new Array(size*size);
				//back = new Array(size*size);
				pta  = new Array(size*size*2);
				ptb  = new Array(size*size*2);
			}
		}
		
		//
		// learned the hard way, that 'new Array(old)' won't copy..
		//
		public function clone():Array
		{
			var z:Array = new Array(bin.length);
			for(var i:int=0; i<bin.length; i++) z[i] = bin[i];
			return z;
		}
		//
		// downsample rgb-img to binary map:
		//
		public function sample( pixel:ByteArray, w:int, h:int, thresh:int=50, snapBG:Boolean=false ):void
		{
			var tw:Number = size/w;
			var th:Number = size/h;
			var nPixel:int= size*size;		
			var i:int;
			
			pixel.position = 0; //@'#!!!

			// select binary (foreground) pixel into bin buffer:
			// it's important to compare rgb values here, because in greyscale
			// there's not much difference between skin and a grey wall.
			var dr:int, dg:int, db:int;
			for ( i=0; i<nPixel; i++ )
			{
				var p:uint = pixel.readUnsignedInt();
				if ( back != null )
				{
					if( snapBG )
						back[i] = p;
					
					dr = ((p    )&0xff - (back[i]    )&0xff);
					dg = ((p>> 8)&0xff - (back[i]>> 8)&0xff);
					db = ((p>>16)&0xff - (back[i]>>16)&0xff);
				}
				else
				{
					dr = ((p    )&0xff);
					dg = ((p>> 8)&0xff);
					db = ((p>>16)&0xff);
				}
				
				//if ( Math.sqrt(dr*dr+dg*dg+db*db) < thresh )
				if ( (dr*dr+dg*dg+db*db) < thresh )
					bin[i] = 0;
				else
					bin[i] = 255;
			}			
		}
		
		// clear all pixels totally surrounded by ON points:
		public function outline(thresh:int):void
		{
			// can't do this inline:
			var pts:Array = new Array(size*size);
			
			// edge detect:
			var k:int=size+1;
			var vm:int=thresh*255;
			for (var j:int=1; j<size-1; j++ )
			{
				for ( var i:int=1; i<size-1; i++ )
				{
					//k=j*size + i;
					// skip, if it's all surrounded by on pixels, or if it's singular 
					var v:Number = bin[k-1-size] + bin[k-size] + bin[k-size+1] + 
							       bin[k-1]			           + bin[k+1] +
								   bin[k+1+size] + bin[k+size] + bin[k+size+1];
					pts[k] = 
						v < 500 ? 0 : 
						( v + bin[k]*4 > vm ) ? 0 : bin[k];
					k++;
				}
				//k+=2;
			}
			//for (k=0; k<size; k++ ) pts[k]=0;
			//for (k=size*(size-1);k<size*size; k++ ) pts[k]=0;
			bin = pts;
		}

		//
		// unidirectional distance between pointsets a and b
		// a and b may have different size!
		//
		private function distance(a:Array, asize:int, b:Array, bsize:int ):int
		{
			var maxDistAB:int = 0;
			for (var i:int=0; i<asize; i+=2)
			{
				var minB:int = 1000000;
				for (var j:int=0; j<bsize; j+=2)
				{
					var dx:int = (a[i]   - b[j]);		
					var dy:int = (a[i+1] - b[j+1]);		
					var ds:int = dx*dx + dy*dy;
					
					if (ds < minB)
					{
						minB = ds;
					}
					if ( ds == 0 )
					{
						break; // can't get better than equal.
					}
				}
				maxDistAB += minB;
			}
			sizeE=sizeA/2;
			return Math.sqrt(maxDistAB);
		}
		
		//
		// calculate the hausdorff distance between
		// our binary and another buffer in the same format:
		//
		public function distanceTo( b:Array ):int
		{	
			// Generate two arrays containing (consecutive x,y) coordinates of ON points
			sizeA=0; sizeB=0;
			for (var i:int=0,k:int=0; i<size; i++)
			{
				for (var j:int=0; j<size; j++)
				{
					if (bin[k] > 1)
					{
						pta[sizeA++]=i;
						pta[sizeA++]=j;
					}
					if (b[k] > 1)
					{
						ptb[sizeB++]=i;
						ptb[sizeB++]=j;
					}
					k++;
				}
			}
			
			var maxDistAB:int = distance( pta, sizeA, ptb, sizeB );
			var maxDistBA:int = distance( ptb, sizeB, pta, sizeA );
			
			return Math.max(maxDistAB,maxDistBA);
		}

	}

}