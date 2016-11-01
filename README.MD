# Introduction

This NetWorker script will recall backups from the Data Domain Cloud Tier. It is meant 
to be used with older versions of NetWorker that are not integrated with Data Domain 
Cloud Tier.

# Installation

In order to use this script Admin Access must be configured on the Data Domain 
system. This allows a remote system with the proper ssh key to use ssh to execute 
commands on the Data Domain without a password. Next the script will need to be
installed on a system with he NetWorker `mminfo` commands. The 
NetWorker server will work best for this, however, any system with the NetWorker 
client installed will also do. Using a Linux NetWorker client may be a good 
solution if the NetWorker server is Windows where this script won't run. The 
user that is used to run the script must have access to the Data Domain ssh key. 

## Configuring Admin Access for Data Domain

1.	From the Linux system where the commands to recall data will be run:

	ssh-keyen –t ecdsa

	Leave the passphrase blank and make note of the location to the id_ecdsa.pub file.

2.	From the host where the keys were generated run the command:

	`ssh <dd_user>@<dd_host> adminaccess add ssh-keys  < ~/.ssh/id_ecdsa.pub`

	Where: <dd_user> is the user on the Data Domain with admin access that will be used to run commands externally. 

	Where: <dd_host> is the name of the Data Domain host that Cloud Tier is on.

	The Data Domain user password will need to be entered for this command.

3.	Verify that Admin Access works by issuing the following command on the Linux system that the ssh key was created on:

	`ssh <dd_user>@<dd_host> filesys show status`

	The status of the Data Domain file system should be displayed. If it is not, login to the Data Domain and verify that 
	they key was taken by running the command: `adminaccess show ssh-keys`

## Install the script

1. Download and copy the `nw_ddct_recall.sh` script to a location where it won't be deleted. 
   For this example we will use `/home/admin` on the NetWorker server. Use the appropriate 
   user on the NetWorker system to do this.
	

2. Set the script to be executable. 

   `chmod 755 nw_ddct_recall.sh`

3.   Verify that the ssh key created for Admin Access is installed in `/home/admin/.ssh`


# Usage

The `nw_ddct_recall.sh` script can be used to locate and recall a single backup based on 
the NetWorker Save Set ID, all backups for a client or all backups for specific or all Data 
Domain systems. Care should be taken if recalling All backups since the recall process 
may take some time and incur additional charges from public cloud providers. 

## Single backup locate and recall

To locate or recall a single backup the operator must first determine the NetWorker Save Set
ID of the backup. This can be done two ways.

### Identifying Save Set ID numbers from the NetWorker Administration GUI

1. Start the NetWorker Administration GUI as a user that can browse clients for restore.

2. Select Media-->Save Sets

3. Fill in the Query Save Set tab with the paramters that will find the backup to be 
   recalled.

4. Select the Save Set List tab.

5. Find the save sets to be recalled in the list and recored the value(s) in the SSID
   column.

### Identifying backup label numbers from the mminfo command line

1. From the command line on the NetWorker server or client run the mminfo command with
   query that includes the save sets to be recllaed and a reprotspec that includes the 
   ssid field (-r 'ssid'). Record the value(s) from the ssid column/field. 
   See the mminfo(8) man page for more detrails. Example:

   `mminfo -q 'client=nw-01,savetime>10/1/2016,savetime<10/8/2016,name=/' -r 'savetime(20),ssid,sumsize,level,volume,name'`
	
	Example:

    ```
    nw-01:~ # mminfo -q 'client=nw-01,savetime>10/1/2016,savetime<10/8/2016,name=/' -r 'savetime(20),ssid,sumsize(8),level,volume(20),name'
     date     time   ssid           size  lvl volume             name
    10/02/16 00:46:33 4226847018 3544 MB full ddve01.001         /
    10/02/16 20:00:06 4075921287 3544 MB full ddve01.001         /
    10/03/16 20:00:06 3925012747  213 KB incr ddve01.001         /
    10/04/16 20:00:06 3774104199  216 KB incr ddve01.001         /
    10/05/16 20:00:06 3623195655  219 KB incr ddve01.001         /
    10/06/16 20:00:06 3472287111  221 KB incr ddve01.001         /
    10/07/16 20:00:06 3321378567  224 KB incr ddve01.001         /
    10/02/16 00:46:33 4226847018 3544 MB full ddve02Clone.001    /
    10/02/16 20:00:06 4075921287 3544 MB full ddve02Clone.001    /
    10/03/16 20:00:06 3925012747  213 KB incr ddve02Clone.001    /
    10/04/16 20:00:06 3774104199  216 KB incr ddve02Clone.001    /
    10/05/16 20:00:06 3623195655  219 KB incr ddve02Clone.001    /
    10/06/16 20:00:06 3472287111  221 KB incr ddve02Clone.001    /
    10/07/16 20:00:06 3321378567  224 KB incr ddve02Clone.001    /
	```

 
## Run `nw_ddct_recall.sh` to locate or recall individual backups   

To list/query backups that are on the Data Domain Cloud Tier run the command below. If backup
files on the Data Domain are listed they are on the Cloud Tier and can be recalled.

`./nw_ddct_recall.sh --ssid save_set_id --sshid ssh_id_file --ddr DD_Host --user DD_User --listonly`

Example:

```
admin@nw-01:~/>: ./nw_ddct_recall.sh --ssid 4075921287 --sshid /home/admin/.ssh/id_ecdsa --ddr ddve-01 --user sysadmin --listonly 
Searching for backup files to recall...
Operating on Data Domain ddve-01
EMC Data Domain Virtual Edition

Looking for save set 1 of 1
Listing or recalling 1 save sets from 2 backup files.
/data/col1/nw-01/dev-01/75/16/b3a3212f-00000006-f2f19f87-57f19f87-000f5000-d0250156
/data/col1/nw-01/dev-01/75/16/notes/b3a3212f-00000006-f2f19f87-57f19f87-000f5000-d0250156

```

To recall the backup from the Data Domain run:

  `./nw_ddct_recall.sh --ssid save_set_id --sshid ssh_id_file --user DD_User`

Example:

```
admin@nw-01:~/>: ./nw_ddct_recall.sh --ssid 4075921287 --sshid /home/admin/.ssh/id_ecdsa --ddr ddve-01 --user sysadmin
Searching for backup files to recall...
Operating on Data Domain ddve-01
EMC Data Domain Virtual Edition

Looking for save set 1 of 1
Listing or recalling 1 save sets from 2 backup files.
EMC Data Domain Virtual Edition
Recall started for "/data/col1/nw-01/dev-01/75/16/b3a3212f-00000006-f2f19f87-57f19f87-000f5000-d0250156". Run the status command to monitor its progress.
EMC Data Domain Virtual Edition
Recall started for "/data/col1/nw-01/dev-01/75/16/notes/b3a3212f-00000006-f2f19f87-57f19f87-000f5000-d0250156". Run the status command to monitor its progress.
EMC Data Domain Virtual Edition
Data-movement to cloud tier:
----------------------------
Data-movement was started on Oct 19 2016 12:58 and completed on Oct 19 2016 13:02
Copied (post-comp): 109.82 KiB, (pre-comp): 8.94 GiB,
Files copied: 144, Files verified: 144, Files installed: 144

Data-movement recall:
---------------------
Data-movement for "/data/col1/nw-01/dev-01/75/16/b3a3212f-00000006-f2f19f87-57f19f87-000f5000-d0250156": Phase 1 of 3 (copying)
Total time: 0:00:02, phase time: 0:00:02, bytes copied: 3.36 GiB

```

## Recalling all data for a client on a specific Data Domain

To recall all data for a client run the command:

`./nw_ddct_recall.sh --all --client client_name --sshid ssh_id_file --user DD_User --ddr DD_Host`
 
 
Example:
 
`admin@nw-01:~/>: ./nw_ddct_recall.sh --all --client nw-01 --sshid /home/admin/.ssh/id_ecdsa --user sysadmin --ddr ddve-01`

## Recalling all data on all Data Domains

To recall all data that NetWorker has backed up on all configured Data Domains run:

`./nw_ddct_recall.sh --all --sshid ssh_id_file --user DD_User`

Example:

`admin@nw-01:~/>: ./nw_ddct_recall.sh --all --sshid /home/admin/.ssh/id_ecdsa --user sysadmin`

# Known Issues

When NetWorker creates an Advanced File Type Device (AFTD) or a Data Domain Boost 
device it creates 3 static files on the disk. They are .nsr, .nsr_serial and volhdr. 
If these files are moved to the Cloud Tier NetWorker will not be able to mount or 
read the volume. To work around this the create date and modified dates of these 
files must be set to sometime in the future. If a problem is being encountered 
now because of this the file should be recalled using one of the procedures below.

To set the files to a future date do the following:

1. Create a CIFS or NFS share on the Data Domain for the MTree that NetWorker users. 
2. Mount that share to a Windows or Unix/Linux system. 
  1. If the MTree is used by DDBoost use the DDBoost username and password of the 
     DDBoost user that owns the LSU. This is most easily done with CIFS and Windows.
3. Locate the three files .nsr, .nsr_serial and volhdr. on the share.
4. If these files had previously been moved to the Cloud Tier, recall them (see 
   the steps below).
5. Verify that the permissions of these files are read/write. If they are not 
   record the current settings and then set them to read/write.
6. Use a utility like touch on Unix/Linux or BulkFileChanger (freeware) on Windows
   to modify the create and modified dates. Setting the dates to 
   1/1/2037 12:00:00am GMT should work well.
7. Set the file permissions back to the way that they were.

# Compatibility

This script was created and tested using NetWorker Virtual Edition v9.0.1 and Data Domain Virtual
Edition v6.0.0.9. 