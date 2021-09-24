

| Item            | Description                           | Type               | Example Value   | Extra                                      |
| --------------- | ------------------------------------- | ------------------ | --------------- | ------------------------------------------ |
| zos_name        | System Name from IEASYSxx             | Text               | S0W1            |                                            |
| zos_version     | z/OS VRM-level                        | Text               | 02.04           |                                            |
| sysplex_name    | Sysplex Name                          | Text               | ADCDPL          |                                            |
| JES             | JES Info                              | Text               | JES2            |                                            |
| Security_Info   | Security Product in use               | Text               | RACF            |                                            |
| CPU_utilisation | CPU Usage reported by SRM (CCVUTILP)  | Numeric (unsigned) | 3               |                                            |
| RCTLACS         | Long-term Average CPU Service Units   | Numeric (unsigned) | 0               |                                            |
| RCTIMGWU        | Workload Units available to MVS image | Numeric (unsigned) | 0               |                                            |
| RCTCECWU        | Workload Units capacity of CEC        | Numeric (unsigned) | 0               |                                            |
| CEC_type        | The CEC Type :)                       | Text               | 1090-306 (ZPDT) |                                            |
| CEC_serial      | CPU Serial                            | Text               | 001250          |                                            |
| CEC_capacity    | Same as RCTCECWU?                     | Numeric (unsigned) | 17              |                                            |
| LPAR_name       | Name of LPAR as defined in HMC        | Text               | PROD1           | For ZPDT it's the Instance User (IBMSYS1?) |
| LPAR_capacity   | Capacity of LPAR                      | Numeric (unsigned) | 32              |                                            |
| VM_name         | Name of z/VM image                    | Text               | GUEST1          | Only available if running in a z/VM image  |
| VM_capacity     | Capacity of z/VM                      | Numeric (unsigned) | 32              | Only available if running in a z/VM image  |
