# borrowings from https://github.com/Frankkkkk/python-pylontech/blob/master/pylontech/pylontech.py

import asyncio, serial, serial_asyncio, re


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
 print(['frame_data', frame_data])
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

 replace = {b'61' : b'42'} # replace map
 while True:
  try:
   c = await read_frame(rinv)
   df = _decode_frame(c)
   print(['rinv', df, df.groups(), df[4]])
   assert df[4] in replace # fail on unfamiliar commands
   l=list(df.groups())
   l[3]=replace[df[4]]
   c=b''.join(l)
   print(['replaced command', c])
   send_cmd(c, wbat)

   c = await read_frame(rbat)
   df = _decode_frame(c)
   print(['rbat', df, df.groups()])
   i = df[6]
   ifnmnc = re.match(b'(..)(..)(..)(.*)',i)
   print(['infoflag', ifnmnc[1], 'numModules', ifnmnc[2], 'numCells', ifnmnc[3], 'rest', ifnmnc[4]])
   nc=int(ifnmnc[3], 16)
   rest=ifnmnc[4][nc*4:]
   cvst=ifnmnc[4][:nc*4]
   cvs=[ int(cvst[i*4:i*4+4], 16) for i in range(0,nc) ]
   print(['cellVs', cvs, 'rest', rest])

#   send_cmd(c, winv)
  except Exception as e:
   print(e)

asyncio.run(main())
