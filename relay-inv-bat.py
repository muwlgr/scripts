# borrowings from https://github.com/Frankkkkk/python-pylontech/blob/master/pylontech/pylontech.py

import asyncio, serial, serial_asyncio, re

async def read_inv(rinv,wbat):
 replace={b'61':b'42'} # replace map
 while True:
  try:
   c = await read_frame(rinv)
   df=_decode_frame(c)
   print(['rinv', df, df.groups(), df[4]])
   assert df[4] in replace # fail on unfamiliar commands
   l=list(df.groups())
   l[3]=replace[df[4]]
   c=b''.join(l)
   print(['replaced command', c])
   send_cmd(c,wbat)
  except Exception as e:
   print(e)

async def read_bat(rbat,winv):
 while True:
  try:
   c = await read_frame(rbat)
   df=_decode_frame(c)
   print(['rbat', df, df.groups()])
   send_cmd(c, winv)
  except Exception as e:
   print(e)

def send_cmd(cmd, writer):
 raw_frame = b'~'+cmd+'{:04X}'.format(get_frame_checksum(cmd)).encode()+b'\r'
 print(['send_cmd', raw_frame])
 writer.write(raw_frame)

def get_frame_checksum(frame):
 sum = 0
 for byte in frame: sum += byte
 sum = ~sum
 sum %= 0x10000
 sum += 1
 return sum

def _decode_hw_frame(raw_frame):
 frame_data = raw_frame[1:len(raw_frame) - 5]
 frame_chksum = raw_frame[len(raw_frame) - 5:-1]

 got_frame_checksum = get_frame_checksum(frame_data)
 assert got_frame_checksum == int(frame_chksum, 16)

 return frame_data

def _decode_frame(frame):
 return re.match(b'(..)(..)(..)(..)(....)(.*)', frame)

async def read_frame(port):
 raw_frame = await port.readuntil(b'\r') # .readline() did not work with serial_asyncio
 print(['read_frame',raw_frame])
 return _decode_hw_frame(raw_frame)

async def main():
 rinv,winv = await serial_asyncio.open_serial_connection(url='/dev/ttyUSB0', baudrate=9600, bytesize=8, parity=serial.PARITY_NONE, stopbits=1, timeout=2, exclusive=True)
 rbat,wbat = await serial_asyncio.open_serial_connection(url='/dev/ttyUSB1', baudrate=9600, bytesize=8, parity=serial.PARITY_NONE, stopbits=1, timeout=2, exclusive=True)
 await asyncio.gather(read_inv(rinv, wbat), read_bat(rbat, winv))

asyncio.run(main())
