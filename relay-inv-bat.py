# borrowings from https://github.com/Frankkkkk/python-pylontech/blob/master/pylontech/pylontech.py

import serial, re

def i16h(i): # format i into 4 hexbin positions
    return '{:04X}'.format(i).encode()

def i8h(i): # format i into 2 hexbin positions
    return '{:02X}'.format(i).encode()

def get_info_length(info):
 lenid = len(info)
 if lenid == 0: return 0

 lenid_sum = (lenid & 0xf) + ((lenid >> 4) & 0xf) + ((lenid >> 8) & 0xf)
 lenid_modulo = lenid_sum % 16
 lenid_invert_plus_one = 0b1111 - lenid_modulo + 1

 return (lenid_invert_plus_one << 12) + lenid

def send_cmd(cmd, writer):
 raw_frame = b'~'+cmd+i16h(get_frame_checksum(cmd))+b'\r'
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
 assert got_frame_checksum == int(frame_chksum, 16), "bad checksum"
 print(['frame_data', frame_data])
 return frame_data

def _decode_frame(frame):
 return re.match(b'(..)(..)(..)(..)(....)(.*)', frame)

def read_frame(port):
 raw_frame = port.read_until(b'\r') # .readline() did not work with serial_asyncio
# raw_frame = port.readline() # .readline() did not work with serial_asyncio
 print(['read_frame',raw_frame])
 return _decode_hw_frame(raw_frame)

def signed(i): # unsigned to signed short
 if i >= 32768: i -= 65536
 return i

def unsigned(i): # signed to unsigned short
 if i < 0: i += 65536
 return i

def maxminind(arr):
 minv=arr[0]
 maxv=arr[0]
 mini=0
 maxi=0
 for i,a in enumerate(arr[1:]):
     if a>maxv :
         maxv=a
         maxi=i+1
     if a<minv :
         minv=a
         mini=i+1
 return [maxv, maxi, minv, mini] 

def main():
 sinv = serial.Serial('/dev/ttyUSB1', 9600, bytesize=8, parity=serial.PARITY_NONE, stopbits=1, timeout=2, exclusive=True)
 sbat = serial.Serial('/dev/ttyUSB0', 9600, bytesize=8, parity=serial.PARITY_NONE, stopbits=1, timeout=2, exclusive=True)

 replace = {b'61' : b'42'} # replace map
 while True:
  try:
   c = read_frame(sinv)
   df = _decode_frame(c)
   print(['rinv', df, df.groups(), df[4]])
   assert df[4] in replace, "unknown command" # fail on unfamiliar commands
   l=list(df.groups())
   l[3]=replace[df[4]]
   c=b''.join(l)
   print(['replaced command', c])
   send_cmd(c, sbat)

   c = read_frame(sbat)
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
   nttr=re.match(b'(..)(.*)', rest)
   nt=int(nttr[1], 16)
   print(['nt', nt, 'rest', nttr[2]])
   ntt=nttr[2][:nt*4]
   rest=nttr[2][nt*4:]
   temps=[ int(ntt[i*4:i*4+4], 16) for i in range(0,nt) ]
   print(['temps', [t-2731 for t in temps], 'rest', rest])
   cvrutc=re.match(b'(....)(....)(....)(..)(....)(....)(.*)', rest)
   cg=cvrutc.groups()
   if cg[-1]==b'' : cg=cg[:len(cg)-1]
   cg=[int(z, 16) for z in cg]
   #cg[0]=signed(cg[0]) # current is signed

   print(['curr', signed(cg[0]), 'volt', cg[1], 'remcap', cg[2], 'udi', cg[3], 'totcap', cg[4], 'cycles', cg[5], 'len', len(cg)])
#now construct a response to command 61h :
   r0=b''.join([df[1], df[2], df[3], df[4]])
   soc=i8h((100*cg[2]-1)//cg[4])
   cyc=i16h(cg[5])
   mmiv=[i16h(i) for i in maxminind(cvs)]
   mmit=[i16h(i) for i in maxminind(temps)]
   faketemp=[i16h(temps[0])] + mmit
   info=[i16h(cg[1]), i16h(unsigned(signed(cg[0])//10)), soc, cyc, cyc, soc, soc] + mmiv + faketemp + faketemp + faketemp
   print(['info61', info, 'len', len(info)])
   joined_info=b''.join(info)
   print(['joined_info', joined_info])
   info_length = i16h(get_info_length(joined_info))
   print(['info_length', info_length])
   frame=r0+info_length+joined_info
   print(['resp61', frame])
   send_cmd(frame, sinv)
  except Exception as e:
   print(e)

if __name__ == '__main__' : main()
