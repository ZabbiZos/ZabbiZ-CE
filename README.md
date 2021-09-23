# ZabbiZ-CE
Public reporitory for ZabbiZ-CE

This repository contains a Zabbix agent for z/OS codename ZabbiZ.
It is a prototype of a "passive" agent.
It is written in REXX
The agent requires a config file. Minimal functional is conf/example.
You do need to change ListenIP to one of your machines home IPs. (tso netstat home).
Optionally also change ListenPort


The configuration file stays as close as possible to the original configuration file on Linux.

The ZabbiZ agent has been tested in combinantion with the Zabbix-server on Linux. 
The portnumber that ZabbiZ listens on (usually 10050) can be set in ZABXCONF.

The code was written as an excersize to learn programming in REXX
I have used many samples from tutorials and fora on the internet 
and am thankfull to everybody who helped me to get this program 
up and running.

Suggestions for improvement:
- using EBCDIC-ASCII tables from the system-files;
- extending the keys that the agent replies the values for;
- programming the options in the configuration file
- etc.
