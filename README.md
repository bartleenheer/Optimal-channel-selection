# Optimal channel selection
## Setup
Place the `change-channel.sh` script on the access point under '/root/' and give it execution permissions by running `chmod +X change-channel.sh`. \[Optional:\] change the `TIMEOUT`, `DEFAULTCHANNEL` and `DEFAULTBANDWIDTH` variables to your preferred values (these can also be specified in the options when running the script).

Make sure there is a wireless network that can be reached by the device that will run the `run.sh` script. 

Put the `run.sh` script onto a device that can execute bash scripts and is able to connect to the access point. \[Optional:\] change the variables to your preferred values (these can also be specified in the options when running the script). Furthermore, make sure you generate an ssh-keyfile (e.g. by using `ssh-keygen`) and register it on the access point.

## Options
When running the `change-channel.sh` script, the following options can be specified:
| Option 	| Default value 	| Description                                                                                               	|
|--------	|---------------	|-----------------------------------------------------------------------------------------------------------	|
| -h     	| -             	| Displays the usage.                                                                                       	|
| -c     	| 44            	| The channel the access point should use.                                                        	|
| -b     	| 20            	| The bandwidth the access point should use.                                                      	|
| -t     	| 90            	| The timeout after which the access point will revert back to the default channel and bandwidth. 	|

When running the `run.sh` script, the following options can be specified:
| Option          	| Default value 	| Description                                                                                                                                                                                               	|
|-----------------	|---------------	|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	|
| -h              	| -             	| Displays the usage.                                                                                                                                                                                       	|
| -i              	| 192.168.1.3   	| The ip address used in the SSH command.                                                                                                                                                                   	|
| -u              	| root          	| The user used in the SSH command.                                                                                                                                                                         	|
| -l              	| log.txt       	| The log filename.                                                                                                                                                                                         	|
| -r              	| result.txt    	| The result filename, when changing this to an existing file in combination with the --skip-search option, the contents of that file will be used to determine the best channel and bandwidth combination. 	|
| -v              	| -             	| When this flag is specified, the output in the commandline will be more verbose.                                                                                                                          	|
| --keyfile       	| ""            	| This option is required in order to make ssh work, it specifies the path of the private key allowed by the access point.                                                                                  	|
| -t              	| 90            	| The timeout. When the connection with the access point is not restored after the specified timeout, it will reset to its default channel and bandwidth.                                                   	|
| --skip-search   	| -             	| Skips the search for the best channel and bandwidth combination, use this if you want to apply the results of a previous run.                                                                             	|
| --skip-optimize 	| -             	| Skips the optimization step and only collects the data for the best channel and bandwidth.                                                                                                                	|