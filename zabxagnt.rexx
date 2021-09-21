/* rexx */
/***************************************************************
** Copyright 2021 - Written by Allard Krings
**
**  Licensed under the Apache License, Version 2.0 (the "License");
**  you may not use this file except in compliance with the License.
**  You may obtain a copy of the License at
**
**     http://www.apache.org/licenses/LICENSE-2.0
**
**  Unless required by applicable law or agreed to in writing,
**  software distributed under the License is distributed on an
**  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
**  either express or implied. See the License for the specific
**  language governing permissions and limitations under the
**  License.
****************************************************************/
call read_config_file
IF ACTIVEAGENT = Y THEN
    call start_active_agent
else
    call start_passive_agent

/***************************************************************/
/* start active Agent                                                */
/***************************************************************/
start_active_agent:
/***************************************************************/
/* ask zabbix-server for active checks */
/***************************************************************/
json_sent = '{"request":"active checks","host":"ZOS4"}'
json_recieved = send_zbxmsg(json_sent)
/***************************************************************/
/* parse json_recieved for active cheks                                 */
/***************************************************************/
i = 0
KEY = ''
DELAY = ''
do while json_recieved <> ''
  parse var json_recieved '{"key":"' json_recieved
  parse var json_recieved key '","delay":' json_recieved
  parse var json_recieved delay ',"lastlogsize":' json_recieved
/***************************************************************/
/*add active checks to the list of keys*/
/***************************************************************/
  IF key <> '' THEN
    DO
      i = i +1
      keyname.i = key
      delay.i = delay
      result = Calculate_Result(keyname.i)
/*    say keyname.i delay.i result */
    END
end
/***************************************************************/
/* Iterate through stem with keys until it is time to send key */
/***************************************************************/
keyname.0 = i
delay.0 = i
i = 0
ls. = 0
do forever
  epoch_days = DATE('B') - 719162
  epoch_hours = epoch_days * 24
  epoch_minutes = epoch_hours * 60
  epoch_seconds =  epoch_minutes * 60
  time = TIME('S')
  epoch = epoch_seconds + time - 3600
  i = i +1
  result = Calculate_Result(keyname.i)
  p1 = '{"request":"agent data", "data":[{"host":"ZOS4",'
  p2 = '"key":"'
  p3 = keyname.i
  p4 = '","value":"'
  p5 = result
  p6 = '",'
  p7 = ' "clock": '||FORMAT(epoch,10,0,0,0)||', "ns": 76808644}],'
  p8 = ' "clock": '||FORMAT(epoch,10,0,0,0)||', "ns": 78808644}'
  json_sent = p1||p2||p3||p4||p5||p6||P7||p8
  if epoch - ls.i > delay.i THEN
    DO
      json_recieved = send_zbxmsg(json_sent)
      ls.i = epoch
    END
    IF i = keyname.0 THEN DO
       i = 0
       CALL SYSCALLS 'ON'
       ADDRESS SYSCALL
       "SLEEP" 1
        CALL SYSCALLS 'OFF'
    END
end
return

/***************************************************************/
/*send zabbix message*/
/***************************************************************/
send_zbxmsg:
/* initializations */
rc = 0
trace off
parse var json_sent
/***************************************************************/
/* Build zabbix message*/
/***************************************************************/
header = 'ZBXD'||D2C(1,1)
l = length(json_sent)
datalength = D2C(l,1)||D2C(0,1)||D2C(0,1)||D2C(0,1)||'00000000'x
zbxmsg = EBCDIC_to_ASCII(header)||datalength||EBCDIC_to_ASCII(json_sent)

/* initialize socketset */
fc = SOCKET('INITIALIZE','ZABBIX')
parse var fc socket_rc .
if socket_rc > 0
then do
  say 'INITIALIZE failed with return info ' fc
  exit 99
end

/* create a TCP socket */
fc = SOCKET('SOCKET')
parse var fc socket_rc newsocketid
if socket_rc >0
then do
  say 'creation of SOCKET failed with return info ' fc
  fc = SOCKET('TERMINATE')
  exit 99
end

/* connect new socket to the specified server */
fc = SOCKET('CONNECT',newsocketid,'AF_INET' 10051 192.168.2.9)
parse var fc connect_rc rest
if connect_rc > 0
then do
  say 'CONNECT failed with return info ' fc
  rc = 99
  signal SHUTDOWN_LABEL
end

/* send zbxmsg to the zabbix server */
fc = SOCKET('send',newsocketid, zbxmsg,'')
parse var fc send_rc num_sent_bytes
if send_rc > 0
then do
  say 'SEND failed with return info ' fc
  rc = 99
  signal SHUTDOWN_LABEL
end

/* plausibility check */
if length(json) > num_sent_bytes
then do
  say 'number of sent bytes does not match number of json_to_send'
  rc = 99
  signal SHUTDOWN_LABEL
end

/* receive answer from zabbix server */
fc = SOCKET('READ',newsocketid)
parse var fc read_rc num_read_bytes reply_ASCII
if read_rc > 0
then do
  say 'READ failed with return info ' fc
  rc = 99
  signal SHUTDOWN_LABEL
end

/* close the socket */
SHUTDOWN_LABEL:
fc = SOCKET('CLOSE',newsocketid)
parse var fc close_rc rest
if close_rc > 0
then do
  say 'CLOSE failed with return info ' fc
  fc = SOCKET('TERMINATE')
  exit 99
end

/* terminate  socketset */
fc = SOCKET('TERMINATE')

/* translate reply from zabbix-server to EBCDIC */
reply_EBCDIC = ASCII_to_EBCDIC(reply_ASCII)

/* strip reply to json-part */
json_recieved = DELSTR(reply_EBCDIC,1,13)

return(json_recieved)

start_passive_agent:
/***************************************************************/
/* Initialize the socket                                       */
/***************************************************************/
fc = SOCKET('INITIALIZE','ZABBXPAS')
parse var fc socket_rc .
if socket_rc > 0
then do
  say 'INITIALIZE failed with return info ' fc
  exit 99
end
/***************************************************************/
/*  Create Socket                                              */
/***************************************************************/
fc = SOCKET('SOCKET','AF_INET','SOCK_STREAM','IPPROTO_TCP')
parse var fc socket_rc newsocketid
if socket_rc > 0
then do
  say 'SOCKET failed with return info ' fc
  fc = SOCKET('TERMINATE')
  exit 99
end
/***************************************************************/
/*  BIND socketid to IP-address and portnumber                 */
/***************************************************************/
Host = "2" ListenPort ListenIP
fc = SOCKET('BIND',newsocketid,Host)
parse var fc bind_rc rest
if bind_rc > 0
then do
  say 'BIND failed with return info ' fc
  fc = SOCKET('CLOSE',newsocketid)
  fc = SOCKET('TERMINATE')
  exit 99
end
/***************************************************************/
/*  Start listening to incoming requests                       */
/***************************************************************/
fc = SOCKET('LISTEN',newsocketid,'10')
parse var fc listen_rc rest
if listen_rc > 0
then do
  say 'LISTEN failed with return info ' fc
  fc = SOCKET('CLOSE',newsocketid)
  fc = SOCKET('TERMINATE')
  exit 99
end
do forever
  fc = SOCKET('ACCEPT',newsocketid)
  parse var fc accept_rc rest
  if accept_rc >0
  then do
    say 'ACCEPT failed with return info ' fc
    fc = SOCKET('CLOSE',newsocketid)
    fc = SOCKET('TERMINATE')
    exit 99
  end
  parse var rest accepted_socket accept_socket_address
  /*fc  = SOCKET( 'SETSOCKOPT', accepted_socket,,
           'IPPROTO_TCP', 'SO_ASCII', 1)
  parse var fc sockopt_rc

  if WORD( fc, 1) <> 0 then
     do
       say 'Error setting socket options'
       say fc
       resp = SOCKET( 'CLOSE', accepted_socket)
       socNum = ''
      end  */
  fc = SOCKET('READ',accepted_socket,'10000')
  parse var fc read_rc num_read_bytes read_string
  if read_rc > 0
  then do
    say 'READ failed with return info ' fc
    rc = 99
    call SHUTDOWN_LABEL
  end
  read_string_e = ASCII_to_EBCDIC(read_string)
/***************************************************************/
/*  Remove header and protocol from read_string                */
/***************************************************************/
  key = DELSTR(read_string_e,1,13)
  kl = length(key)
/***************************************************************/
/*  Close the program if key = 99                              */
/***************************************************************/
  IF key = 99
  then do
    fc = SOCKET('CLOSE',newsocketid)
    say 'zabbix agent stopped'
    parse var fc close_rc rest
    if close_rc > 0
    then do
      say 'CLOSE failed with return info ' fc
      exit 99
    end
    call SHUTDOWN_LABEL
  end
/***************************************************************/
/*  Calculate result based on input key and create packet      */
/***************************************************************/
  r = Calculate_Result(key)
  l = length(r)
/***************************************************************/
/*  Create packet                                              */
/***************************************************************/
  packet_p1  = EBCDIC_to_ASCII('ZBXD'||D2C(1,1))
  packet_p2 = D2C(l,1)||D2C(0,1)||D2C(0,1)||D2C(0,1)||'00000000'x
  packet_p3 = EBCDIC_to_ASCII(r)
  packet = packet_p1||packet_p2||packet_p3
/***************************************************************/
/*  Send packet                            */
/***************************************************************/
  fc = SOCKET('SEND',accepted_socket,packet,'')
  parse var fc send_rc num_sent_bytes
  if send_rc > 0
  then do
     say 'SEND failed with return info ' fc
     rc = 99
     call SHUTDOWN_LABEL
  end
  read_string =' '
  fc = SOCKET('CLOSE',accepted_socket)
  parse var fc close_rc rest
  if close_rc > 0
  then do
    say 'CLOSE failed with return info ' fc
    fc = SOCKET('TERMINATE')  exit 99
  end
end

SHUTDOWN_LABEL:
fc = SOCKET('CLOSE',accepted_socket)
parse var fc close_rc rest
if close_rc > 0
then do
  say 'CLOSE failed with return info ' fc
  fc = SOCKET('TERMINATE')  exit 99
end
say 'CLOSE succeeded with return info ' fc
fc = SOCKET('TERMINATE')
exit

/***************************************************************/
/*  Calculate send_string based on key-value in read_string    */
/***************************************************************/
Calculate_Result: Procedure
parse arg read_string

SELECT
/***************************************************************/
/*  Get z/OS name                                              */
/***************************************************************/
  WHEN read_string = 'zos_name' THEN
    DO
      cvtaddr = get_dec_addr(16)
      zos_name = Strip(Storage(D2x(cvtaddr+340),8))
      send_string = zos_name
    END
/***************************************************************/
/*  Get z/OS version                                           */
/***************************************************************/
  WHEN read_string = 'zos_version' THEN
    DO
      cvtaddr = get_dec_addr(16)
      ecvtaddr = get_dec_addr(cvtaddr+140)
      zos_ver = Strip(Storage(D2x(ecvtaddr+512),2))
      zos_rel = Strip(Storage(D2x(ecvtaddr+514),2))
      zos_ver_rel = zos_ver || '.' || zos_rel
      send_string = zos_ver_rel
    END
/***************************************************************/
/*  Get Sysplex name                                           */
/***************************************************************/
  WHEN read_string = 'sysplex_name' THEN
    DO
      cvtaddr = get_dec_addr(16)
      ecvtaddr = get_dec_addr(cvtaddr+140)
      sysplex_name = Strip(Storage(D2x(ecvtaddr+8),8))
      send_string = sysplex_name
    END
/***************************************************************/
/*  Get JES Information                                        */
/***************************************************************/
  WHEN read_string = 'JES' THEN
    DO
      JES =  SYSVAR('SYSJES')  '.' SYSVAR('SYSNODE') || ')'
      send_string = JES
    END
/***************************************************************/
/*  Get Security System Information                            */
/***************************************************************/
  WHEN read_string = 'Security_Info' THEN
    DO
      cvtaddr = get_dec_addr(16)
      cvtrac = get_dec_addr(cvtaddr+992)
      rcvtid = Storage(d2x(cvtrac),4)
      If rcvtid = 'RCVT' Then Security_Info = 'RACF'
      If rcvtid = 'RTSS' Then Security_Info = 'CA Top Secret'
      If rcvtid = 'ACF2' Then Security_Info = 'CA ACF2'
      send_string = Security_Info
    END
/***************************************************************/
/*  Get CPU utilisation                                        */
/***************************************************************/
  WHEN read_string = 'CPU_utilisation' THEN
    DO
      CALL C2D_GET
      send_string = CCVUTILP
    END
  WHEN read_string = 'RCTLACS' THEN
    DO
      CALL C2D_GET
      send_string = RCTLACS
    END
  WHEN read_string = 'RCTIMGWU' THEN
    DO
      CALL C2D_GET
      send_string = RCTIMGWU
    END
  WHEN read_string = 'RCTCECWU' THEN
    DO
      CALL C2D_GET
      send_string = RCTCECWU
    END
  OTHERWISE
    DO
    CALL IWMQVS_GET
    SELECT
/***************************************************************/
/* Get CEC type                                                */
/***************************************************************/
      WHEN read_string = 'CEC_type' THEN
        DO
           CEC_type_description =  cec_type || '-' || Strip(cec_model) cec_desc
           send_string = CEC_type_description
        END
/***************************************************************/
/* Get CEC serial                                              */
/***************************************************************/
      WHEN read_string = 'CEC_serial' THEN
        DO
           send_string = cec_serial
        END
/***************************************************************/
/* Get CEC capacity                                            */
/***************************************************************/
      WHEN read_string = 'CEC_capacity' THEN
        DO
          If cec_cap_valid = 1 Then
             proc_cap = C2d(Substr(QVS_out,65,4))
          ELSE
             proc-cap = '0'
          send_string = proc_cap
        END
/***************************************************************/
/* Get LPAR name                                               */
/***************************************************************/
      WHEN read_string = 'LPAR_name' THEN
        DO
          lparname = Strip(Substr(QVS_out,69,8))
          If lparname = '' THEN
            LPAR_name = 'Not running under an LPAR'
          Else
            LPAR_name = lparname
          send_string = LPAR_name
        END
/***************************************************************/
/* Get LPAR capacity                                           */
/***************************************************************/
      WHEN read_string = 'LPAR_capacity' THEN
        DO
          If lpar_cap_valid = 1 Then
              Do
              lpar_cap = C2d(Substr(QVS_out,81,4))
              LPAR_capacity = 'LPAR Capacity' lpar_cap 'MSU'
              end
          Else
            LPAR_capacity = '0'
          send_string = LPAR_capacity
        END
/***************************************************************/
/* Get z/VM image name                                         */
/***************************************************************/
        WHEN read_string = 'VM_name' THEN
          DO
            vmname = Strip(Substr(QVS_out,85,8))
            If vmname = '0000000000000000'x then
              VM_name = 'Not running under a z/VM image'
            Else
              VM_name = vmname
            send_string = VM_name
          END
/***************************************************************/
/* Get z/VM capacity                                           */
/***************************************************************/
        WHEN read_string = 'VM_capacity' THEN
          DO
            If vm_cap_valid = 1 Then
               Do
               vm_cap = C2d(Substr(QVS_out,93,4))
               send_string = vm_cap
               END
            Else
              send_string = 'ZBXD_UNSUPPORTED'
          END
        OTHERWISE
        send_string = 'ZBXD_UNSUPPORTED'
      END
    END
END
return (send_string)

/***************************************************************/
/* Read 4 hr MSU average, Image defined MSUs, CEC MSU Capacity */
/***************************************************************/

C2D_GET:
CVT      = C2d(Storage(10,4))
RMCT     = C2d(Storage(D2x(CVT+604),4))
RCT      = C2d(Storage(D2x(RMCT+228),4))
RMCTCCT  = C2d(Storage(D2x(RMCT+4),4))
CCVUTILP = C2d(Storage(D2x(RMCTCCT+102),2))
RCTLACS  = C2d(Storage(D2x(RCT+196),4))
RCTIMGWU = C2d(Storage(D2x(RCT+28),4))
RCTCECWU = C2d(Storage(D2x(RCT+32),4))
return

/***************************************************************/
/*  Call IWMQVS to get MSU, LPAR and z/VM Info                 */
/* - Setup parameters and output area                          */
/* - Call IWMQVS                                               */
/* - Process capacity flags                                    */
/* - Output Processor model and type                           */
/***************************************************************/

IWMQVS_GET:
QVS_Outlen = 500
QVS_Outlenx = Right(x2c(d2x(QVS_Outlen)),4,d2c(0))
QVS_Out = QVS_Outlenx || Copies('00'X,QVS_Outlen-4)
Address Linkpgm 'IWMQVS QVS_Out'
If rc > 0 Then Say "Error from IWMQVS, rc = " || rc
qvs_flag = C2x(substr(QVS_Out,6,1))
cec_cap_valid = Substr(X2b(qvs_flag),1,1)
lpar_cap_valid = Substr(X2b(qvs_flag),2,1)
vm_cap_valid = Substr(X2b(qvs_flag),3,1)
cec_type = Substr(QVS_Out,9,4)
cec_model = Substr(QVS_Out,13,12)
cec_serial = Substr(QVS_Out,39,6)
Select
  When cec_type = '2064' Then cec_desc = '(z Series 900)'
  When cec_type = '2066' Then cec_desc = '(z Series 800)'
  When cec_type = '2084' Then cec_desc = '(z Series 990)'
  When cec_type = '2086' Then cec_desc = '(z Series 890)'
  When cec_type = '2094' Then cec_desc = '(System z9 EC)'
  When cec_type = '2096' Then cec_desc = '(System z9 BC)'
  When cec_type = '2097' Then cec_desc = '(System z10 EC)'
  When cec_type = '2098' Then cec_desc = '(System z10 BC)'
  When cec_type = '2817' Then cec_desc = '(zEnterprise 196)'
  When cec_type = '2818' Then cec_desc = '(zEnterprise 114)'
  When cec_type = '2827' Then cec_desc = '(zEnterprise EC12)'
  When cec_type = '2964' Then cec_desc = '(z System z13)'
  When cec_type = '2965' Then cec_desc = '(z System z13s)'
  When cec_type = '3906' Then cec_desc = '(IBM Z z14)'
  When cec_type = '3907' Then cec_desc = '(IBM Z z14 ZR1)'
  When cec_type = '8561' Then cec_desc = '(IBM Z z15)'
  Otherwise cec_desc = ''
return

/***************************************************************/
/*  get_dec_addr                                               */
/*                                                             */
/*     Function to return address stored at address passed     */
/*                                                             */
/*     Input:  addr = address of storage holding address needed*/
/*     Output: four bytes at addr (in decimal)                 */
/***************************************************************/

get_dec_addr: Procedure
Parse Arg addr
hex_addr = d2x(addr)
stor = Storage(hex_addr,4)
hex_stor = c2x(stor)
value = x2d(hex_stor)
Return value

/***************************************************************/
/*       ASCII To EBCDIC                                       */
/***************************************************************/
ASCII_to_EBCDIC: Procedure
parse arg ASCII_data

a2etab = '00010203 372D2E2F 1605250B 0C0D0E0F'x || ,
         '10111213 3C3D3226 18193F27 1C1D1E1F'x || ,
         '405A7F7B 5B6C507D 4D5D5C4E 6B604B61'x || ,
         'F0F1F2F3 F4F5F6F7 F8F97A5E 4C7E6E6F'x || ,
         '7CC1C2C3 C4C5C6C7 C8C9D1D2 D3D4D5D6'x || ,
         'D7D8D9E2 E3E4E5E6 E7E8E9AD E0BD5F6D'x || ,
         '79818283 84858687 88899192 93949596'x || ,
         '979899A2 A3A4A5A6 A7A8A9C0 4FD0A107'x || ,
         '20212223 24150617 28292A2B 2C090A1B'x || ,
         '30311A33 34353608 38393A3B 04143EFF'x || ,
         '41AA4AB1 9FB26AB5 BBB49A8A B0CAAFBC'x || ,
         '908FEAFA BEA0B6B3 9DDA9B8B B7B8B9AB'x || ,
         '64656266 63679E68 74717273 78757677'x || ,
         'AC69EDEE EBEFECBF 80FDFEFB FCBAAE59'x || ,
         '44454246 43479C48 54515253 58555657'x || ,
         '8C49CDCE CBCFCCE1 70DDDEDB DC8D8EDF'x

EBCDIC_data = translate(ASCII_data,a2etab)
return EBCDIC_data

/***************************************************************/
/*       EBCDIC To ASCII                                       */
/***************************************************************/

EBCDIC_to_ASCII: Procedure
parse arg EBCDIC_data

e2atab = '00010203 04050607 08090A0B 0C0D0E0F'x || ,
         '10111213 14151617 18191A1B 1C1D1E1F'x || ,
         '20212223 24252627 28292A2B 2C2D2E2F'x || ,
         '30313233 34353637 38393A3B 3C3D3E3F'x || ,
         '20414243 44454647 48499C2E 3C282B7C'x || ,
         '26515253 54555657 58592124 2A293B5F'x || ,
         '2D2F6263 64656667 68697C2C 255F3E3F'x || ,
         '70717273 74757677 78603A23 40273D22'x || ,
         '80616263 64656667 68698A8B 8C8D8E8F'x || ,
         '906A6B6C 6D6E6F70 71729A9B 9C9D9E9F'x || ,
         'A07E7374 75767778 797AAAAB AC5BAEAF'x || ,
         'B0B1B2B3 B4B5B6B7 B8B9BABB BC5DBEBF'x || ,
         '7B414243 44454647 4849CACB CCCDCECF'x || ,
         '7D4A4B4C 4D4E4F50 5152DADB DCDDDEDF'x || ,
         '5CE15354 55565758 595AEAEB ECEDEEEF'x || ,
         '30313233 34353637 3839FAFB FCFDFEFF'x
 ASCII_data = translate(EBCDIC_data, e2atab)
 return ASCII_data

/***************************************************************/
/*       Read the zabbix-agent configuration file ZABXCONF     */
/***************************************************************/

read_config_file:
/*address TSO*/
INPUT_FILE = 'IBMUSER.PROGRAMS.REXX(ZABXCONF)'
"ALLOC DD(INPUT) DS('"INPUT_FILE"') SHR"
"EXECIO * DISKR INPUT (STEM cFID. FINIS)"
"free file(INPUT)"

/*this will contain all the  bad VARs. */
bad=
/*  "    "     "     "   "  good   "   */
CONFIGVARLIST=
BAD=
/*zero all these variables.*/
maxLenV=0
blanks=0
hashes=0
semics=0
badVar=0

/* j counts the lines in the file.*/
/* read a line (record) from the file  */
do j=1  to cFID.0
    /*  ··· & strip leading/trailing blanks*/
    txt = strip(cFID.j)
    /*count # blank lines.*/
    if txt ='' then
      do
        blanks=blanks+1
        iterate
      end
    if left(txt,1)=='#' then
      do
        hashes=hashes+1
        iterate
      end
      /*  "   " lines with #*/
    if left(txt,1)==';' then
      do
        semics=semics+1
        iterate
      end
    eqS=pos('=',txt)
    /*we can't use the   TRANSLATE   BIF.  */
    if eqS\==0  then

      /*replace the first  '='  with a blank.*/
      txt=overlay(' ',txt,eqS)

    /*get the variable name and it's value.*/
    parse var txt configvariable configvalue
    call value configvariable, configvalue
    upper configvariable

    /*strip leading and trailing blanks.   */
    configvalue=strip(configvalue)

    /*if no value,  then use   "true".     */
    if configvalue ='' then
        configvalue = 'true'
   /*can REXX utilize the variable name ? */
    if symbol(configvariable)=='BAD'  then
      do
        badVar=badVar+1
         /*append to list*/
        BADCONFIGVARLIST=BADCONFIGVARLIST configvariable
        iterate
      end
    /*add it to the list of good variables.*/
    CONFIGVARLIST = CONFIGVARLIST configvariable
    /*now,  use VALUE to set the variable. */

    /*maxLen of varNames,  pretty display. */
    maxLenV=max(maxLenV,length(configvalue))

end

/*j*/
vars=words(CONFIGVARLIST)
@ig= 'ignored that began with a'
say #(j)      'record' s(j)  'were read from file:  ZABXCONF'
if blanks\==0  then
  say #(blanks)  'blank record's(blanks) "were read."
if hashes\==0  then
  say #(hashes)  'record's(hashes)   @ig   "#  (hash)."
if semics\==0  then
  say #(semics)  'record's(semics)   @ig   ";  (semicolon)."
if badVar\==0  then
  say #(badVar)  'bad variable name's(badVar) 'detected:' bad
say
say 'The list of'    vars    "variable"s(vars)    'and',
  s(vars,'their',"it's")       "value"s(vars)       'follows:'
say
do k=1  for vars
   v=word(CONFIGVARLIST,k)
   say right(v,maxLenV) '=' value(v)
end
say
return
s:
if arg(1)==1  then
  return arg(3)
return word(arg(2) 's',1)

#:
/*right justify a number & also indent.*/
return right(arg(1),length(j)+11)

err:
do j=1  for arg()
  say '***error***    ' arg(j)
  say
end

/*j*/
exit 13
novalue:
syntax:
call err 'REXX program' condition('C') "error",,
     condition('D'),'REXX source statement (line' sigl"):",,
     sourceline(sigl)
return