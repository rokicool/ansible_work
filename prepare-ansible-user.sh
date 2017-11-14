#!/bin/bash 
# v0.1 by rokicool
#
# This script is supposed to prepare machine to be managed from anstible server.
# It will:
#  1. create ansible group and user
#  2. make changes to allow this user to sudo without a password
#  3. create authirized_keys file to allow remote connection authorized by key

ANSIBLE_GROUP=ansible
ANSIBLE_GID=1499
ANSIBLE_USER=ansible
ANSIBLE_UID=1499

AUTH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC56DZ56CMl4e8aYIfhRY7+IHa8BbXqUpq7BTQpdozRVQBGQ7QkmTVO6/b/8AjGkK2XzIJUQrT8kboNiPkTFdSkPREwJwUglIyVbw8Hy+jJG7oz+uOCYGa4ntZtxkQ7yydpTnWCPE0qtgD8N31gaiJ5668G5xiXMeKh4VAV772CIDidfZs8vQPh2TioaFxPNrLD+H1SXkyjOxhYBdGnKccaT9IZgwEh75+G8p+keeHEN0jBeSJByumppDGMdRNGAMAAVhO8osQhTnXVuKT9QMKWWx/vHzGceaBwl6XmCiyNEdKm9wYLfVNsDZCzO07XwKLdILJ/ "

AUTH_USER=ansible@sf-ansible-01

print_help() {
   echo ""
   echo This script is supposed to prepare machine to be managed from anstible server.
   echo It will:
   echo - create ansible group and user
   echo - make changes to allow this user to sudo without a password
   echo - create authirized_keys file to allow remote connection authorized by key 
   echo ""
}

check_if_user_exist() {
   # $1 - username to check
   #
   # RETURNS:
   #  0 - user $1 exists
   #  1 - user $1 does NOT exist

   id -u $1 > /dev/null 2>&1
   return $?
}

check_if_group_exist() {
   # $1 - groupname to check
   # 
   # RETURNS:
   #  0 - group $1 exists
   #  1 - group $1 does NOT exist
   
   grep -q -E "^${1}:" /etc/group > /dev/null
}

create_user() {
   # $1 - username to create
   # $2 - groupname to put user
   # $3 - uid to assign to the user
   #
   # RETURNS:
   #  0 - the user created sucsessfully
   #  1 - there was a mistake when creating a user
   
   # the membership of the user is slighlty different in different versions of Linux
   # we only support Ubuntu 14.04 and higher and CentOS7 and higher
 
   DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
   case "${DISTRO}" in
      "CentOS Linux")
         ADM_GROUP=wheel
         ;;
      "Ubuntu")
         ADM_GROUP=admin
         ;;
      *)
         (>&2 echo ERROR. We only support Ubuntu and CentOS7 )
         exit 1
   esac

   #sudo useradd -b /home -g ansible -m -u 1499 -c "Tech Account" -s /bin/bash -G admin ansible
   sudo useradd -b /home -g ${2} -m -u ${3} -c "Tech Account" -s /bin/bash -G ${ADM_GROUP} ${1}
   
}



# make suer we are runnunt as root 

if [ "$EUID" -ne 0 ]; then
   print_help
   echo ""
   echo "This script MUST be runnig with ROOT privileges"
   echo ""
   exit 1
fi

# check if the group ${ANSIBLE_GROUP} exist
if ! check_if_group_exist ${ANSIBLE_GROUP} ; then
   # group  ${ANSIBLE_GROUP} does NOT exist - creating
   groupadd -g ${ANSIBLE_GID} ${ANSIBLE_GROUP} 
fi

# check if the user ${ANSIBLE_USER} exist
if ! check_if_user_exist ${ANSIBLE_USER} ; then
   # user ${ANSIBLE_USER} does NOT exist - creating
   create_user ${ANSIBLE_USER} ${ANSIBLE_GROUP} ${ANSIBLE_UID}
fi

# allow ansible to sudo without a password

echo ansible ALL = NOPASSWD : ALL > /etc/sudoers.d/ansible

# create or update authorized_keys

if [ ! -d /home/${ANSIBLE_USER}/.ssh ]; then
   # there is no such directory - create it
   mkdir /home/${ANSIBLE_USER}/.ssh
   chown ${ANSIBLE_USER}:${ANSIBLE_GROUP} /home/${ANSIBLE_USER}/.ssh
   chmod 700 /home/${ANSIBLE_USER}/.ssh
fi


if [ ! -f /home/${ANSIBLE_USER}/.ssh/authorized_keys ]; then
   # there is no such file - create it
   touch /home/${ANSIBLE_USER}/.ssh/authorized_keys 
   chown ${ANSIBLE_USER}:${ANSIBLE_GROUP} /home/${ANSIBLE_USER}/.ssh/authorized_keys
   chmod 600 /home/${ANSIBLE_USER}/.ssh/authorized_keys
fi

# check if $AUTH_USER is already listed in authorized_keys
grep -q -E "${AUTH_USER}" /home/${ANSIBLE_USER}/.ssh/authorized_keys > /dev/null
if [ $? -ne 0 ] ;then
   # there is no such string in authorized_keys - add it!
   echo ${AUTH_KEY}${AUTH_USER} >> /home/${ANSIBLE_USER}/.ssh/authorized_keys
fi

