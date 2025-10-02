#!/bin/bash
echo 117 >/sys/class/gpio/export
echo out >/sys/class/gpio/gpio117/direction
echo 1 >/sys/class/gpio/gpio117/value
#actualizar hora:
# date -s `curl -I 'https://google.com/' 2>/dev/null | grep -i '^date:' | sed 's/^[Dd]ate: //g'`


/usr/sbin/swapoff -a

STATION="TECHOUTAD_"
BITRATE="16"
SAMPLE_RATE="32000"
GAIN="5.0"
DURATION="10"
IDRECORDER="1"
PROGRAMS_DIR=/home/orangepi
SLEEPDURATION="1"

IPSERVER=10.4.117.10
USER=utad
#SERVERDIR=/home/utad/Escritorio/datos_audios_bd/datosUtadAux/
SERVERDIR=/home/utad/Escritorio/datos_audios_bd/datos_audios_bd/audio_data/10

while :
do
        FILE=`date +"%Y-%m-%d %T"`
        DIRECTORY=`date +"%Y-%m-%d"`
        DATE=$FILE
        FILE=${FILE//:/_}
        FILE=${FILE// /_}
#       echo "$FILE"
#
        sox -t alsa hw:1 -r $SAMPLE_RATE -b $BITRATE -c 1 $PROGRAMS_DIR/recordings/$STATION$FILE.wav trim 0 $DURATION sinc -n 32767 $BANDPASS_FILTER  2>&1 >/dev/null
#DESCOMENTAR PARA ENVIAR A BASE DE DATOS y CAMBIAR PUERTO
        #curl -X POST -H "Content-Type: multipart/form-data" \
        #-F "json_data={\"file_1\": {\"filename\": \"$STATION$FILE.wav\",\"id_recorder_recordings\": \"$IDRECORDER\", \"time_record\": \"${DATE%.WAV}\",\"filetype_record\": \".wav\", \"bitrate_record\": \"$BITRATE\",\"sample_rate_record\": \"$SAMPLE_RATE\",\"gain_record\": \"$GAIN\",\"duration_record\": \"$DURATION\"}}" \
        #-F "file_1=@$PROGRAMS_DIR/recordings/$STATION$FILE.wav" \
        # http://$IPSERVER:5000/api/v1/insert_files
        mkdir -p $PROGRAMS_DIR/sdBackup/$DIRECTORY
        $PROGRAMS_DIR/spectrogram/spectrogram $PROGRAMS_DIR/recordings/$STATION$FILE.wav
        mv $PROGRAMS_DIR/recordings/$STATION$FILE.wav* $PROGRAMS_DIR/sdBackup/$DIRECTORY/


#         TEMP=`cat /sys/class/thermal/thermal_zone0/temp`
#         BOARD_TEMP=$(awk '{printf("%d",$1/1000)}' <<<${TEMP})
#         LINE=`$PROGRAMS_DIR/DHT22/dht22.out`
#         DATA=($LINE)
#         BOX_TEMP=${DATA[0]}
#         BOX_HUMIDITY=${DATA[1]}
#         MSG="echo $DATE BOARD_TEMP $BOARD_TEMP ºC BOX_TEMP $BOX_TEMP ºC BOX_HUMIDITY $BOX_HUMIDITY %$STATION$FILE.wav >> $STATION_opi.log"
#         echo  "$MSG" > $PROGRAMS_DIR/stats.txt
# #       ssh $USER@$IPSERVER $MSG
#         scp  $PROGRAMS_DIR/sdBackup/$DIRECTORY/$STATION$FILE.wav $USER@$IPSERVER:$SERVERDIR
#         sleep $SLEEPDURATION

        # SENSORES DE HUMEDAD Y TEMPERATURA
        TEMP=`cat /sys/class/thermal/thermal_zone0/temp` # Temperatura
        BOARD_TEMP=$(awk '{printf("%d",$1/1000)}' <<<${TEMP})
        LINE=`$PROGRAMS_DIR/DHT22/dht22`  # Sensor de humedad
        DATA=($LINE)
        BOX_TEMP=${DATA[0]}
        BOX_HUMIDITY=${DATA[1]}
        # TEXTO PLANO
        MSG="echo $DATE BOARD_TEMP $BOARD_TEMP ºC BOX_TEMP $BOX_TEMP ºC BOX_HUMIDITY $BOX_HUMIDITY % $STATION$FILE.wav >> $STATION.log"
        echo  "$MSG" >> $PROGRAMS_DIR/stats.txt
        ssh $USER@$IPSERVER $MSG
        ssh $USER@$IPSERVER mkdir -p /datos2/AM$STATION/
        scp  $PROGRAMS_DIR/sdBackup/$DIRECTORY/$STATION$FILE.wav $USER@$IPSERVER:/datos2/AM$STATION/
        sleep $SLEEPDURATION



done