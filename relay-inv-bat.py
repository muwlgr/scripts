# borrowings from https://github.com/Frankkkkk/python-pylontech/blob/master/pylontech/pylontech.py
# also with invaluable knowledge gained from https://github.com/Frankkkkk/python-pylontech/blob/master/RS485-protocol-pylon-low-voltage-V3.3-20180821.pdf
# and from a very helpful combined manual in Ukrainian from https://greenpowertalk.tech/threads/komunikacija-invertora-anenji-6-2kw-i-batareji-dyness-b4850.1543/post-35618

# how to use: 
# on your Dyness B3, turn on only DIP2, the rest (1,3,4) leave turned off
# on your inverter, ensure that your battery type is set to LIL or to other type mentioning PYLON and RS485 in its description
# get 2 USB-RS485 adapters, connect them to your inverter and battery, plug them into your Linux host, check their persistent names by running
# ls -l /dev/serial/*/*
# check what inverter sends using
# cu -l /dev/serial/X/Y-port0 -s 9600
# (find the proper inverter's port, on which you will receive ASCII chars starting from ~20024661... ,
# and the other will be from the battery)
# configure these port names in serial.Serial(...) constructors down in this script
# and run it using python3 . remove debug printout when you stop needing it .
# report observed problems to mwg@mwg.dp.ua or to https://greenpowertalk.tech/members/muwlgr.11768/

import serial, re

def fenc(f,i): return f.format(i).encode()

def i16h(i): return fenc('{:04X}', i) # format i into 4 hexbin positions

def i8h(i):  return fenc('{:02X}', i) # format i into 2 hexbin positions

def signed(i): # unsigned to signed short
 if i >= 32768: i -= 65536
 return i

def unsigned(i): # signed to unsigned short
 if i < 0: i += 65536
 return i

def ai16(b): # parse array of shorts prepended with 8-bit length
 n=int(b[:2], 16)
 v1=b[2:]
 vv=[ int(v1[i:i+4], 16) for i in [ j*4 for j in range(0, n) ] ]
 rest=v1[n*4:]
# print(['a16i', b, '=', n, vv, rest])
 return n, vv, rest

def maxminind(arr): #find max and min values in the array together with their indices
 minv=arr[0]
 maxv=arr[0]
 mini=0
 maxi=0
 for i in range(1,len(arr)):
     a=arr[i]
     if a>maxv :
         maxv=a
         maxi=i
     if a<minv :
         minv=a
         mini=i
# print(['mmiv', arr, '=', [maxv, maxi, minv, mini]])
 return [maxv, maxi, minv, mini] 

def get_info_length(info):
 lenid = len(info)
 if lenid == 0: return 0

 lenid_sum = (lenid & 0xf) + ((lenid >> 4) & 0xf) + ((lenid >> 8) & 0xf)
 lenid_modulo = lenid_sum % 16
 lenid_invert_plus_one = 0b1111 - lenid_modulo + 1

 return (lenid_invert_plus_one << 12) + lenid # copied from Frankkkkk

def send_cmd(cmd, writer):
 raw_frame = b'~'+cmd+i16h(get_frame_checksum(cmd))+b'\r'
 print(['send_cmd', raw_frame])
 writer.write(raw_frame) # copied from Frankkkkk
# writer.flush()

def get_frame_checksum(frame):
 sum = 0
 for byte in frame: sum += byte
 sum = ~sum
 sum %= 0x10000
 sum += 1
 return sum # copied from Frankkkkk

def _decode_hw_frame(raw_frame):
 frame_data = raw_frame[1:len(raw_frame) - 5]
 frame_chksum = raw_frame[len(raw_frame) - 5:-1]

 got_frame_checksum = get_frame_checksum(frame_data)
 assert got_frame_checksum == int(frame_chksum, 16), "bad checksum"
# print(['frame_data', frame_data])
 return frame_data # copied from Frankkkkk

def _decode_frame(frame):
 return re.match(b'(..)(..)(..)(..)(....)(.*)', frame)

def read_frame(port):
 raw_frame = port.read_until(b'\r') # .readline() did not work with serial_asyncio
# raw_frame = port.readline() # .readline() did not work with serial_asyncio
# print(['read_frame',raw_frame])
 return _decode_hw_frame(raw_frame) # copied from Frankkkkk

def main():
 sinv = serial.Serial(port='/dev/serial/by-path/pci-0000:00:14.0-usb-0:5.1:1.0-port0', baudrate=9600, bytesize=8, parity=serial.PARITY_NONE, stopbits=1, timeout=2, exclusive=True)
 sbat = serial.Serial(port='/dev/serial/by-path/pci-0000:00:14.0-usb-0:1:1.0-port0', baudrate=9600, bytesize=8, parity=serial.PARITY_NONE, stopbits=1, timeout=2, exclusive=True)

 replace = {b'61' : b'42'} # replace map
 while True:
  try:
   c = read_frame(sinv)
   df = _decode_frame(c)
   print(['rinv', df.groups()])
   assert df[4] in replace, ["unknown command", df[4]] # fail on unfamiliar commands
   l=list(df.groups())
   l[3]=replace[l[3]]
   c=b''.join(l)
   print(['replaced command', c])
   send_cmd(c, sbat)

   c = read_frame(sbat)
   df = _decode_frame(c)
   print(['rbat', df.groups()])
   ifnmnc = re.match(b'(..)(..)(.*)', df[6])
   print(['if, nm, rest', ifnmnc.groups()]) # infoflag, "Command value" (?)
   nc, cvs, rest = ai16(ifnmnc[3])
   print(['nc, cellV, rest', [nc, cvs, rest]]) #number of cells, cell voltages, rest
   nt, temps, rest = ai16(rest)
   print(['nt, temps, rest', [nt, [t-2731 for t in temps], rest]]) # number of temps, temperatures, rest

   cg=list(re.match(b'(....)(....)(....)(..)(....)(....)(.*)', rest).groups()) # current, voltage, remaining capacity, "User defined items", total capacity, cycles
   if cg[3] == b'02' and cg[6] == b'': cg.pop()
   elif cg[3] == b'04' and len(cg[6]) == 12:
    rt=re.match('(......)(......)', cg[6]) # 24-bit remaining capacity, 24-bit total capacity
    cg[2]=rt[1]
    cg[4]=rt[2]
    cg.pop()
   else: assert False, ['bad _UserDefinedItems', cg[3], rest]

   cg=[int(z, 16) for z in cg]

   print(['curr', signed(cg[0]), 'volt', cg[1], 'remcap', cg[2], 'udi', cg[3], 'totcap', cg[4], 'cycles', cg[5], 'len', len(cg)]) # current is signed
#now construct a response to command 61h :
   r0=b''.join([df[1], df[2], df[3], df[4]]) # copy battery's response header into the "synthetic" response
   soc=i8h((100*cg[2]-1)//cg[4])
   cyc=i16h(cg[5])
   mmiv=[i16h(i) for i in maxminind(cvs)] # create voltage array for 0x61 response
   mmit=[i16h(i) for i in maxminind(temps)] # create temperature array for 0x61 response
   faketemp=[i16h(temps[0])] + mmit # take temps[0] as "average temp"
   info=[i16h(cg[1]), i16h(unsigned(signed(cg[0])//10)), soc, cyc, cyc, soc, soc] + mmiv + faketemp + faketemp + faketemp # concatenate the main part of 0x61 response format
   print(['info61', info, 'len', len(info)])
   joined_info=b''.join(info)
   print(['joined_info', joined_info])
   info_length = i16h(get_info_length(joined_info))
   print(['info_length', info_length])
   frame=r0+info_length+joined_info # prepend response header and length
   print(['resp61', frame])
   send_cmd(frame, sinv) # send it to the inverter with checksum
  except Exception as e:
   print(e)

if __name__ == '__main__' : main()
