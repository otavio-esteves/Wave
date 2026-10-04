"""Original gravel, rock and conifer cutouts; no third-party game assets."""
from pathlib import Path
import math, random, struct, zlib
OUT = Path(__file__).resolve().parents[2] / 'assets/textures/rally'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(20261004)
N = 1024

def png(name, data, n):
    def chunk(k, d):
        return struct.pack('!I', len(d)) + k + d + struct.pack('!I', zlib.crc32(k+d))
    raw = b''.join(b'\0'+data[y*n*4:(y+1)*n*4] for y in range(n))
    (OUT/(name+'.png')).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',n,n,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))

for name in ['gravel','rock']:
    data = bytearray(N*N*4)
    heights = [0.]*(N*N)
    for y in range(N):
        for x in range(N):
            broad = math.sin(x*math.tau/N*3)*math.sin(y*math.tau/N*2)*8
            grain = rng.uniform(-14,14)
            c = 115+broad+grain if name=='gravel' else 90+broad+grain
            data[(y*N+x)*4:(y*N+x+1)*4] = bytes((int(c),int(c*.90),int(c*.76),255))
            heights[y*N+x] = grain*.002
    # Embedded angular stones, periodically wrapped to preserve seamless tiling.
    for _ in range(22000 if name=='gravel' else 6000):
        cx,cy = rng.randrange(N),rng.randrange(N)
        radius = rng.uniform(1,5) if name=='gravel' else rng.uniform(3,12)
        c = rng.randrange(78,170)
        for oy in range(-int(radius),int(radius)+1):
            for ox in range(-int(radius),int(radius)+1):
                if abs(ox)*.8+abs(oy)*1.2>radius: continue
                x,y = (cx+ox)%N,(cy+oy)%N
                light = int(c+ox*2-oy*3)
                data[(y*N+x)*4:(y*N+x+1)*4] = bytes((light,int(light*.94),int(light*.84),255))
                heights[y*N+x] = .2*(1-(abs(ox)+abs(oy))/(radius*2))
    png(name,data,N)
    normals=bytearray(N*N*4)
    for y in range(N):
        for x in range(N):
            dx=(heights[y*N+(x+1)%N]-heights[y*N+(x-1)%N])*2
            dy=(heights[((y+1)%N)*N+x]-heights[((y-1)%N)*N+x])*2
            length=math.sqrt(1+dx*dx+dy*dy)
            normals[(y*N+x)*4:(y*N+x+1)*4]=bytes((int(127.5-127.5*dx/length),int(127.5-127.5*dy/length),int(127.5+127.5/length),255))
    png(name+'_normal',normals,N)

N=512
data=bytearray(N*N*4)
# Branches taper upward; many needles break the outline into irregular sprays.
for layer in range(27):
    cy=66+layer*15
    width=12+layer*6
    for branch in range(7):
        for _ in range(420):
            t=rng.random()
            side=rng.choice([-1,1])
            x=int(256+side*width*t+rng.gauss(0,5))
            y=int(cy+t*13+rng.gauss(0,4))
            if 0<=x<N and 0<=y<N:
                c=rng.randrange(29,74)
                data[(y*N+x)*4:(y*N+x+1)*4]=bytes((int(c*.74),c,int(c*.65),255))
for y in range(58,510):
    for x in range(253,260):
        if data[(y*N+x)*4+3]==0:
            data[(y*N+x)*4:(y*N+x+1)*4]=bytes((69,60,47,255))
png('conifer',data,N)
print('Saved five original rally textures')
