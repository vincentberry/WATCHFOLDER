#!/bin/bash
#BY VINCENT BERRY | WATCHFOLDER 
#------------------variable------------------------------

declare -A     TabDossier=([abwatchfolder]="./watchfolder" [ablogs]="./watchfolder/logs" [inbox]="./watchfolder/inbox" [outbox]="./watchfolder/outbox" \
[archives]="./watchfolder/archives" [sources]="./watchfolder/sources" [encoding]="./watchfolder/encoding" [errors]="./watchfolder/errors")

#------------------fonction------------------------------ 

#Gestion des logs avec $1=INFO;ERROR $2=message du logs
function funcLog {
        #Vérifie la présence du dossier log.
        if [ -d "${TabDossier[ablogs]}" ]; then    
                
                #création du fichier s’il n'est pas présent
                for varlog in "log" "ffmpeg" "errors"; do

                        if [ ! -r "${TabDossier[ablogs]}/`date +%y-%m-%d`.$varlog" ]; then
                                #création de fichier log
                                touch "${TabDossier[ablogs]}/`date +%y-%m-%d`.$varlog"
                                echo "`date +%y/%m/%d-%T.%3N` INFO"'      '"Fichier `date +%y-%m-%d`.$varlog crée">>"${TabDossier[ablogs]}/`date +%y-%m-%d`.$varlog"
                                echo -e '\E[37;44m'"\033[1m`date +%y/%m/%d-%T.%3N`\033[00m" '\E[37;42m'"\033[1mINFO\033[00m"'      '"Fichier `date +%y-%m-%d`.$varlog crée"
                        fi

                done

                #INFO LOG
                if [ $1 = "INFO" ]; then
                        #ajouter dans le fichier log
                        echo "`date +%y/%m/%d-%T.%3N` $1        $2">>"${TabDossier[ablogs]}/`date +%y-%m-%d`.log"
                        #afficher dans le terminal
                        echo -e '\E[37;44m'"\033[1m`date +%y/%m/%d-%T.%3N`\033[00m" '\E[37;42m'"\033[1m$1\033[00m"'      '"$2"

                #error LOG
                elif [ $1 = "ERROR" ]; then
                        #ajouter dans le fichier log
                        echo "`date +%y/%m/%d-%T.%3N` $1        $2">>"${TabDossier[ablogs]}/`date +%y-%m-%d`.errors" 
                        #afficher dans le terminal               
                        echo -e '\E[37;44m'"\033[1m`date +%y/%m/%d-%T.%3N`\033[00m" '\E[37;41m'"\033[1m$1\033[00m"'     '"$2"
                fi

        #Si le dossier log n'est pas présent
        else
                #affiche le message reçu dans le terminal
                echo -e '\E[37;44m'"\033[1m`date +%y/%m/%d-%T.%3N`\033[00m" '\E[37;42m'"\033[1m$1\033[00m" "     $2"
                #affiche que le dossier log n'est pas présent
                echo -e '\E[37;44m'"\033[1m`date +%y/%m/%d-%T.%3N`\033[00m" '\E[37;41m'"\033[1mERROR\033[00m"'     ''\E[37;41m'"\033[1mATTENTE DE LA CRÉATION DES FICHIERS lOGS\033[00m"
        fi
}

#Vérifie la présence des dossiers mis en arguments
function funcDossier {
        for varDossier in $@; do

                #Vérifie que le dossier mis dans varDossier est présent
                if [ -d "$varDossier" ]; then
                        #Logs 
                        funcLog "INFO" "Dossier $varDossier OK"  
                
                #le dossiers n'est pas présent     
                else
                        mkdir "$varDossier"
                        #Logs
                        funcLog "INFO" "Dossier $varDossier crée." 
                fi

        done
}

#Vérifie que les dossiers mis en arguments sont toujours présent pendant l'execution du script
function funcDcheck {

        for varDossier in $@; do
               
                #Vérifie que les dossiers ne sont plus présent
                if [ ! -d "$varDossier" ]; then
                        #création d'un nouveau file log crach à la racine du script
                        touch "crach_watchfolder.log"
                        #logs crach
                        echo "`date +%y/%m/%d-%T.%3N` CRACH        Fichier supprimer">>"crach_watchfolder.log"  
                        echo -e '\E[37;44m'"\033[1m`date +%y/%m/%d-%T.%3N`\033[00m" '\E[37;41m'"\033[1mCRACH\033[00m"'     ''\E[37;41m'"\033[1mErreur critique: demande de restart\033[00m"
                        
                        #crée les dossiers manquant
                        funcDossier "${TabDossier[@]}"
                        #Logs
                        cat "crach_watchfolder.log">>"${TabDossier[ablogs]}/`date +%y-%m-%d`.errors"
                        funcLog "ERROR" "Erreur critique: Fichier supprimer"
                fi

        done

}

#MEDIA INFO avec $1=nom du fichier
function funcMediainfo {

        #Vérification que le fichier ne soit pas en cours ingest
        funcIngest "${TabDossier[inbox]}/$1"

        #variable
        varTaille="`ls -l ${TabDossier[inbox]}/$1 |awk '{print $5}'`"
        varTailletranfert="0"
        varName="`date +%y-%m-%d_%H%M`_$1"

        #logs
        funcLog "INFO" "Check mediainfo audio/video: $1"

        #Si le fichier est autre qu'une video+audio, la commande mediainfo ne retourne rien
        if [[ -z `mediainfo --Inform="Video;%Format%" "${TabDossier[inbox]}/$1"` && -z `mediainfo --Inform="Audio;%Format%" "${TabDossier[inbox]}/$1"` ]]; then

                #logs
                funcLog "ERROR" "Fichier $1 non valable. Erreur audio/video"
                funcLog "ERROR" "Transfert de $1 vers ${TabDossier[errors]}"

                #Déplacer le fichier corrompu  
                funcTranfert "${TabDossier[inbox]}/$1" "${TabDossier[errors]}/$varName" "ERROR"
                  
        else
                #logs
                funcLog "INFO" "Fichier $1: OK"
                funcLog "INFO" "Transfert de $1 vers ${TabDossier[encoding]}"

                #Déplacer le fichier  
                funcTranfert "${TabDossier[inbox]}/$1" "${TabDossier[encoding]}/$varName" "INFO"

                #logs
                funcLog "INFO" "Le fichier $varName va etre encoder !"

                #lancement de l'encoding
                funcFfmpeg "$varName"


        fi
}

#Attend la fin du tranfert avec $1=origine $2=destination $3=logs[ERROR;INFO]
function funcTranfert {

        #Variable
        varTaille=`ls -l $1 |awk '{print $5}'`
        varTailletranfert="0"

        #Déplace le fichier 
        mv  $1 $2

        #boucle tant que le fichier est en cours de copie
        while [[ "$varTailletranfert" -lt  "$varTaille" ]]; do

                varTailletranfert=`ls -l $2 |awk '{print$5}'`
                varResultat=$(echo "scale=2;a=$varTailletranfert/$varTaille;a*100" | bc -l)

                #logs
                funcLog "$3" "$varResultat% - Tranfert de $(basename $1) vers $(dirname  $2) EN COURS."

                sleep 2

        done

        #logs
        funcLog "$3" "Fichier $(basename $1) à était renommer $(basename $1)."
        funcLog "$3" "Fichier $(basename $1) déplacé vers $(dirname  $2)."
}

#Vérifie que le media n'est pas en cours ingest avec $1=dossier+fichier
function funcIngest {

        #Variable
        varTaille=`ls -l $1 |awk '{print $5}'`
        varTailletranfert="0"

        #boucle tant que le fichier est en cours de copie
        while [[ "$varTailletranfert" -lt  "$varTaille"  ]]; do

                        varTailletranfert=$varTaille
                        varTaille=`ls -l $1 |awk '{print $5}'`

                        #logs
                        funcLog "INFO" "fichier $(basename $1) en cours ingest"

                        sleep  5
        done
}

#FFmpeg avec $1=fichier
function funcFfmpeg {
        #variable 
        varName=${1%%.???}"_encoding.mp4" 

        #logs
        funcLog "INFO" "encodage en cours: $1"
        
        #FFmpeg
        ffmpeg -ss 30 -t 20 -i "${TabDossier[encoding]}/$1"  -vf "yadif=0:-1,scale=320:trunc((320/(iw/ih))/2)*2" -c:v h264 -b:v 600k -g 120 -r 25 -c:a aac -b:a 128k -f mp4 "${TabDossier[encoding]}/$varName" \
        2> "${TabDossier[ablogs]}/`date +%y-%m-%d`.ffmpeg"         #retourne les logs de ffmpeg

        #logs
        funcLog "INFO" "encodage terminer: $varName" 
        funcLog "INFO" "verfication du fichier: $varName"

        #Si ffmpeg renvoi une erreur
        if [ $? -ne 0 ]; then

                #logs
                funcLog "ERROR" "fichier corrompu: $varName"

                #tranfert des fichier vers la destination final
                funcTranfert "${TabDossier[encoding]}/$1" "${TabDossier[sources]}/$1" "ERROR"
                funcTranfert "${TabDossier[encoding]}/$varName" "${TabDossier[errors]}/erreur_$varName" "ERROR"

                #logs
                funcLog "ERROR" "Les fichier corrompu ont était déplacer"
        
        #Si ffmpeg renvoi pas erreur
        else
                #logs
                funcLog "INFO" "fichier OK: $varName"
                
                #tranfert des fichier vers la destination final
                funcTranfert "${TabDossier[encoding]}/$1" "${TabDossier[archives]}/$1" "INFO"
                funcTranfert "${TabDossier[encoding]}/$varName" "${TabDossier[outbox]}/$varName" "INFO"

                #logs
                funcLog "INFO" "TERMINER: $varName"
        fi
}

#------------------SCRIPT------------------------------ 

#INITIALIZATION du watchfolder
#logs GO
funcLog "INFO" "INITIALIZATION WATCHFOLDER"

#Logs
funcLog "INFO" "VÉRIFICATION DES DEPENDANCE"


#Appel la verfication des dossiers
funcDossier ${TabDossier[@]}

#logs init terminer
funcLog "INFO" "INITIALIZATION WATCHFOLDER TERMINER"

#boucle watchfolder
while (true); do

        #Checks que les dossier sont toujours présent
        funcDcheck ${TabDossier[@]}

        #Regarde si un dossier est tomber dans inbox
        for varFile in  `ls -t ${TabDossier[inbox]} 2>"0"`; do

                if [ -n $varFile ]; then
                        funcLog "INFO" "fichier trouvé: $varFile"   #Logs   
                        funcMediainfo "$varFile"
                fi

        done

        #action possible par utilisateur

        read -t 1 varUser

        if [ ! -z $varUser ]; then
                #kill tous les process watchfolder
                if [ $varUser = "exit" ]; then
                        #logs
                        funcLog "INFO" "Demande User: watchfolder kill"

                        kill -9 $(pgrep -f watchfolder.sh)

                #Test le watchfolder
                elif [ $varUser = "test" ]; then

                        #Logs
                        funcLog "INFO" "Demande User: Test - téléchargement en cours ..." 

                        touch "watchfolder.testOn"
                        echo '#!/bin/bash'>"watchfolder.testOn"
                        echo '$(wget -P $1 http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_native_60fps_normal.mp4 2>"0")'>>"watchfolder.testOn"
                        echo '$(wget -P $1 http://classics.mit.edu/Homer/iliad.mb.txt 2>"0")'>>"watchfolder.testOn"
                        echo '$(rm -r watchfolder.testOn 2>"0")'>>"watchfolder.testOn"
                        $(chmod 777 watchfolder.testOn)
                        $(./watchfolder.testOn "${TabDossier[inbox]}")

                #Taper une commande dans le terminal
                elif [ $varUser = "com" ]; then
                        #Logs
                        funcLog "INFO" "Demande User: entrée une commande"

                        read $varCommande
                        echo $($varCommande)

                else
                        #logs
                        funcLog "ERROR" "Demande User: commande non interprète"

                echo 'commande disponible "exit" "test" "com"'
                fi
        fi

done