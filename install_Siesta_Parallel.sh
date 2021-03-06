#!/bin/bash
#Instalação no Ubuntu 18.04.05 do SIESTA 4.1-b3
########################################################################################
#0. Objetivo: Este documento contém instruções passo a passo para prosseguir com uma (esperançosamente) instalação bem-sucedida do software SIESTA (Iniciativa Espanhola para Simulações Eletrônicas com Milhares de Átomos) no Linux (testado com Ubuntu 18.04) usando as ferramentas GCC e OpenMPI para paralelismo. Para obter uma construção paralela do SIESTA, você deve primeiro determinar que tipo de paralelismo você precisa. É aconselhável usar MPI para cálculos com um número moderado de núcleos. Para centenas de threads, o paralelismo híbrido usando MPI e OpenMP pode ser necessário.
########################################################################################
#0.0 Atualizando o sistema
echo "Iniciando a instalação do Siesta em Paralelo"
sudo apt-get update
echo "Atualizando o sistema"
sudo apt-get upgrade -y
########################################################################################
#1. Instalando os pré-requisitos: Presumimos que você esteja executando todos os comandos abaixo como um usuário comum (não root), portanto, usamos sudo quando necessário. Isso porque mpirun NÃO gosta de ser executado como root.
echo "Instalando os pré-requisitos"
sudo apt install python python3 -y
sudo apt install build-essential g++ gfortran libreadline-dev m4 xsltproc -y
# Agora instale o software e bibliotecas OpenMPI ou MPICH:
sudo apt install openmpi-common openmpi-bin libopenmpi-dev -y
sudo apt-get install make -y
#OU , se preferir, instale a implementação mpich do MPI:
# sudo apt install mpich libcr-dev -y
#NÃO instale os dois pacotes (OpenMPI e MPICH).
########################################################################################
#2. Criando os diretórios de instalação
echo "Criando os diretórios de instalação"
SIESTA_DIR=/opt/siesta
OPENBLAS_DIR=/opt/openblas
SCALAPACK_DIR=/opt/scalapack
CALCULATIONS_DIR=/home/$USER/Siesta
mkdir $CALCULATIONS_DIR
sudo mkdir $SIESTA_DIR $OPENBLAS_DIR $SCALAPACK_DIR
# permissões temporariamente perdidas (reverteremos mais tarde)
sudo chmod -R 777 $SIESTA_DIR $OPENBLAS_DIR $SCALAPACK_DIR
########################################################################################
#3. Instalando as bibliotecas: Para executar o siesta em paralelo usando MPI, você precisa de bibliotecas de blas e lapack não threaded junto com uma biblioteca de scalapack padrão.
echo "Instalando as bibliotecas"
#3.1 Instale a biblioteca openblas de single-thread: o apt instala uma versão encadeada do openblas por padrão, eu acho que isso não é adequado para esta compilação MPI do siesta.
cd $OPENBLAS_DIR
wget -O OpenBLAS.tar.gz https://ufpr.dl.sourceforge.net/project/openblas/v0.3.7/OpenBLAS%200.3.7%20version.tar.gz
tar xzf OpenBLAS.tar.gz && rm OpenBLAS.tar.gz
cd "$(find . -type d -name xianyi-OpenBLAS*)"
make DYNAMIC_ARCH=0 CC=gcc FC=gfortran HOSTCC=gcc BINARY=64 INTERFACE=64 \
  NO_AFFINITY=1 NO_WARMUP=1 USE_OPENMP=0 USE_THREAD=0 USE_LOCKING=1 LIBNAMESUFFIX=nonthreaded
make PREFIX=$OPENBLAS_DIR LIBNAMESUFFIX=nonthreaded install
cd $OPENBLAS_DIR && rm -rf "$(find $OPENBLAS_DIR -maxdepth 1 -type d -name xianyi-OpenBLAS*)"
#3.2 Instale o scalapack: Responda b quando for perguntado.
mpiincdir="/usr/include/mpich"
if [ ! -d "$mpiincdir" ]; then mpiincdir="/usr/lib/x86_64-linux-gnu/openmpi/include" ; fi
cd $SCALAPACK_DIR
wget http://www.netlib.org/scalapack/scalapack_installer.tgz -O ./scalapack_installer.tgz
tar xf ./scalapack_installer.tgz
mkdir -p $SCALAPACK_DIR/scalapack_installer/build/download/
wget https://github.com/Reference-ScaLAPACK/scalapack/archive/v2.1.0.tar.gz -O $SCALAPACK_DIR/scalapack_installer/build/download/scalapack.tgz
cd ./scalapack_installer
./setup.py --prefix $SCALAPACK_DIR --blaslib=$OPENBLAS_DIR/lib/libopenblas_nonthreaded.a \
  --lapacklib=$OPENBLAS_DIR/lib/libopenblas_nonthreaded.a --mpibindir=/usr/bin --mpiincdir=$mpiincdir
########################################################################################
#4. Instalando o SIESTA no diretório previamente informado
echo "Instalando o Siesta"
cd $SIESTA_DIR
wget https://launchpad.net/siesta/4.1/4.1-b3/+download/siesta-4.1-b3.tar.gz
tar xzf ./siesta-4.1-b3.tar.gz && rm ./siesta-4.1-b3.tar.gz
#4.1 Instale as dependências da biblioteca siesta: 
#4.1.1 Instalando o flook
cd $SIESTA_DIR/siesta-4.1-b3/Docs
wget https://github.com/ElectronicStructureLibrary/flook/releases/download/v0.7.0/flook-0.7.0.tar.gz
(./install_flook.bash 2>&1) | tee install_flook.log
#4.1.2 Instalando o netcdf (Esse demora bastante, caso der erro verifique o loginstall_netcdf4.log)
cd $SIESTA_DIR/siesta-4.1-b3/Docs
wget https://zlib.net/fossils/zlib-1.2.11.tar.gz
#caso der erro deve baixar manualmente
wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.18/src/hdf5-1.8.18.tar.bz2
wget -O netcdf-c-4.4.1.1.tar.gz https://github.com/Unidata/netcdf-c/archive/v4.4.1.1.tar.gz
wget -O netcdf-fortran-4.4.4.tar.gz https://github.com/Unidata/netcdf-fortran/archive/v4.4.4.tar.gz
(./install_netcdf4.bash 2>&1) | tee install_netcdf4.log
#4.2 Baixar o arch.make
cd $SIESTA_DIR/siesta-4.1-b3/Obj
wget -O arch.make https://raw.githubusercontent.com/bgeneto/siesta-gcc-mpi/master/gcc-mpi-arch.make
#4.3 Construir o execultável do Siesta
cd $SIESTA_DIR/siesta-4.1-b3/Obj
sh ../Src/obj_setup.sh
make OBJDIR=Obj
########################################################################################
#5. Copiando o Siesta para um local mais adequado
echo "Copiando o Siesta"
cd $SIESTA_DIR/siesta-4.1-b3/Obj
sudo cp siesta /usr/local/bin
########################################################################################
# CASO JÁ TENHA INSTALADO O SIESTA EM SERIAL NA MÁQUINA DESMARQUE ESSE BOX E ATENTE PARA O LOCAL ONDE FOI INSTALADO O SIESTA
########################################################################################
#6. Reverter as permissões de super usuário
echo "Revertendo as permissões"
sudo chown -R root:root $SIESTA_DIR $OPENBLAS_DIR $SCALAPACK_DIR
sudo chmod -R 755 $SIESTA_DIR $OPENBLAS_DIR $SCALAPACK_DIR
#7.Criar pasta SIESTA_Calculations
#teste 
cd $CALCULATIONS_DIR 
wget https://github.com/DjardielGomes/Siesta/archive/refs/heads/main.zip
unzip main.zip
mv Siesta-main Git-Hub
rm main.zip
#Testando com o grafeno
cd Git-Hub/Teste_Opt_Graphene
mpirun -np 4 siesta -in C2.fdf |tee C2.out
#USE ESSE BLOCO PARA SITUAÇÕES QUE NÃO EXISTE NENHUMA VERSÃO DO SIESTA INSTALADA
########################################################################################
#echo "Execultando o Siesta em paralelo"
cd 
siesta
#poweroff
########################################################################################
#EXEMPLO DE COMO RODAR
#mpirun -np 4 siesta < C2.fdf |tee C2.out

#Script adaptado de Bernhard Enders por Djota.

