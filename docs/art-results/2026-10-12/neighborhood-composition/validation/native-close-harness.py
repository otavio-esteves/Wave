import ctypes as C
import os, subprocess, time
from pathlib import Path
root=Path('/home/otavio/Projects/Wave')
logpath=root/'docs/art-results/2026-10-12/neighborhood-composition/validation/native-menu.log'
class Data(C.Union):
    _fields_=[('b',C.c_char*20),('s',C.c_short*10),('l',C.c_long*5)]
class Client(C.Structure):
    _fields_=[('type',C.c_int),('serial',C.c_ulong),('send_event',C.c_int),('display',C.c_void_p),('window',C.c_ulong),('message_type',C.c_ulong),('format',C.c_int),('data',Data)]
class Event(C.Union):
    _fields_=[('type',C.c_int),('client',Client),('pad',C.c_long*24)]
x=C.CDLL('libX11.so.6');x.XOpenDisplay.argtypes=[C.c_char_p];x.XOpenDisplay.restype=C.c_void_p
x.XDefaultRootWindow.argtypes=[C.c_void_p];x.XDefaultRootWindow.restype=C.c_ulong
x.XInternAtom.argtypes=[C.c_void_p,C.c_char_p,C.c_int];x.XInternAtom.restype=C.c_ulong
x.XGetWindowProperty.argtypes=[C.c_void_p,C.c_ulong,C.c_ulong,C.c_long,C.c_long,C.c_int,C.c_ulong,C.POINTER(C.c_ulong),C.POINTER(C.c_int),C.POINTER(C.c_ulong),C.POINTER(C.c_ulong),C.POINTER(C.POINTER(C.c_ubyte))]
x.XFree.argtypes=[C.c_void_p];x.XSendEvent.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_long,C.POINTER(Event)];x.XFlush.argtypes=[C.c_void_p];x.XCloseDisplay.argtypes=[C.c_void_p]
display=x.XOpenDisplay(None)
if not display:raise RuntimeError('Cannot connect to X11 for this native test')
rootwin=x.XDefaultRootWindow(display)
def atom(name):return x.XInternAtom(display,name.encode(),0)
def values(window,key):
    actual=C.c_ulong();fmt=C.c_int();count=C.c_ulong();remaining=C.c_ulong();data=C.POINTER(C.c_ubyte)()
    result=x.XGetWindowProperty(display,window,atom(key),0,4096,0,0,C.byref(actual),C.byref(fmt),C.byref(count),C.byref(remaining),C.byref(data))
    try:
        if result or fmt.value!=32 or not data:return []
        return list(C.cast(data,C.POINTER(C.c_ulong))[:count.value])
    finally:
        if data:x.XFree(data)
env=os.environ.copy();env['XDG_DATA_HOME']='/tmp/wave-oct12-native-clean';env['DRI_PRIME']='1'
with logpath.open('w') as log:
    proc=subprocess.Popen([str(root/'builds/linux/Wave.x86_64'),'--display-driver','x11'],cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
    try:
        window=None
        for attempt in range(120):
            if proc.poll() is not None:raise RuntimeError(f'Native app exited before close: {proc.returncode}')
            for candidate in values(rootwin,'_NET_CLIENT_LIST'):
                if values(candidate,'_NET_WM_PID')==[proc.pid]:window=candidate;break
            if window is not None:break
            time.sleep(0.25)
        if window is None:raise RuntimeError('No X11 window belonging to the native test process')
        time.sleep(5)
        event=Event();event.client.type=33;event.client.send_event=1;event.client.display=display;event.client.window=window;event.client.message_type=atom('WM_PROTOCOLS');event.client.format=32;event.client.data.l[0]=atom('WM_DELETE_WINDOW');event.client.data.l[1]=0
        if not x.XSendEvent(display,window,0,0,C.byref(event)):raise RuntimeError('Cannot send close to the native test window')
        x.XFlush(display)
        code=proc.wait(timeout=30)
        log.write(f'\nNative menu opened and received WM_DELETE_WINDOW; exit_code={code}\n');log.flush()
        if code:raise RuntimeError(f'Native menu returned {code}')
        print('Native Linux menu opened and closed normally, exit 0.')
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:proc.wait(timeout=10)
            except subprocess.TimeoutExpired:proc.kill();proc.wait()
        x.XCloseDisplay(display)
