#!/usr/bin/env bash

set -e

OMADA_DIR="/data"
ARCH="${ARCH:-}"
OMADA_URL="https://static.tp-link.com/upload/software/2022/202208/20220822/Omada_SDN_Controller_v5.5.6_Linux_x64.tar.gz"
OMADA_MAJOR_VER="$(echo "${OMADA_VER}" | awk -F '.' '{print $1}')"




# extract required data from the OMADA_URL
OMADA_TAR="$(echo "${OMADA_URL}" | awk -F '/' '{print $NF}')"
OMADA_VER="$(echo "${OMADA_TAR}" | awk -F '_v' '{print $2}' | awk -F '_' '{print $1}')"
OMADA_MAJOR_VER="${OMADA_VER%.*.*}"
OMADA_MAJOR_MINOR_VER="${OMADA_VER%.*}"

die() { echo -e "$@" 2>&1; exit 1; }

# common package dependencies
PKGS=(
  gosu
  net-tools
  openjdk-17-jre-headless
  tzdata
  wget
)

case "${ARCH}" in
amd64|arm64|"")
  PKGS+=( mongodb-server-core )
  ;;
armv7l)
  PKGS+=( mongodb )
  ;;
*)
  die "${ARCH}: unsupported ARCH"
  ;;
esac

# output variables/selections
echo "ARCH=${ARCH}"
echo "OMADA_VER=${OMADA_VER}"
echo "OMADA_TAR=${OMADA_TAR}"
echo "OMADA_URL=${OMADA_URL}"
echo "PKGS=( ${PKGS[*]} )"

echo "**** Install Dependencies ****"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-install-recommends -y "${PKGS[@]}"

echo "**** Download Omada Controller ****"
cd /tmp
wget -nv "${OMADA_URL}"

echo "**** Extract and Install Omada Controller ****"


# in the 4.4.3, 4.4.6, and 4.4.8 builds, they removed the directory. this case statement will handle variations in the build
case "${OMADA_VER}" in
  4.4.3|4.4.6|4.4.8)
    echo "version ${OMADA_VER}"
    mkdir "Omada_SDN_Controller_${OMADA_VER}"
    cd "Omada_SDN_Controller_${OMADA_VER}"
    tar zxvf "../${OMADA_TAR}"
    rm -f "../${OMADA_TAR}"
    ;;
  *)
    echo "not version 4.4.3/4.4.6/4.4.8"
    tar zxvf "${OMADA_TAR}"
    rm -f "${OMADA_TAR}"
    cd Omada_SDN_Controller_*
    ;;
esac


mkdir -p /data/db

# make sure tha the install directory exists
mkdir "${OMADA_DIR}" -vp
mkdir "${OMADA_DIR}/logs"
mkdir "${OMADA_DIR}/work"
mkdir "${OMADA_DIR}/data"
mkdir "${OMADA_DIR}/data/pdf"
mkdir "${OMADA_DIR}/data/dbd"

#create default files

touch "${OMADA_DIR}/IMAGE_OMADA_VER.txt"

#ln -s /data /opt/tplink/EAPController

# starting with 5.0.x, the installation has no webapps directory; these values are pulled from the install.sh
case "${OMADA_MAJOR_VER}" in
  5)
    NAMES=( bin properties lib install.sh uninstall.sh )
    ;;
  *)
    NAMES=( bin properties keystore lib webapps install.sh uninstall.sh )
    ;;
esac


# copy over the files to the destination
for NAME in "${NAMES[@]}"
do
  cp "${NAME}" "${OMADA_DIR}" -r
done

# symlink to home assistant data dir
#ln -s /data "${OMADA_DIR}"

# symlink for mongod
ln -sf "$(which mongod)" "${OMADA_DIR}/bin/mongod"
chmod 755 "${OMADA_DIR}"/bin/*

echo "${OMADA_VER}" > "${OMADA_DIR}/IMAGE_OMADA_VER.txt"

echo "**** Setup omada User Account ****"
groupadd -g 508 omada
useradd -u 508 -g 508 -d "${OMADA_DIR}" omada
chown -R omada:omada "${OMADA_DIR}/data" "${OMADA_DIR}/logs" "${OMADA_DIR}/work"


echo "**** Cleanup ****"
rm -rf /tmp/* /var/lib/apt/lists/*
