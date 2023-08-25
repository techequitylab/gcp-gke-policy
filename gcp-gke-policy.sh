#!/bin/bash
# 
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
#
#################################################################################
##############   Explore Network Policy with Sample Hello App    ################
#################################################################################

function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-gke-policy > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-gke-policy
export SCRIPTNAME=gcp-gke-policy.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=us-east4
export GCP_ZONE=us-east4-a
export GCP_CLUSTER=gcp-gke-cluster
EOF
source $PROJDIR/.env
fi

export APPLICATION_NAME=netpolicy

# Display menu options
while :
do
clear
cat<<EOF
===============================================
Configure Kubernetes Network Security policies
-----------------------------------------------
Please enter number to select your choice:
(1) Enable APIs
(2) Create Kubernetes cluster
(3) Explore network policies 
(G) Launch user guide
(Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export GCP_CLUSTER=$GCP_CLUSTER
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud application project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 5
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export GCP_CLUSTER=$GCP_CLUSTER
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud application project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "$ gcloud services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs" | pv -qL 100
    gcloud services enable cloudapis.googleapis.com container.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud beta container clusters create \$GCP_CLUSTER --zone \$GCP_ZONE --machine-type e2-standard-2 --num-nodes 2 --labels location=\$GCP_REGION --spot --enable-network-policy # to create cluster" | pv -qL 100
    echo
    echo "$ gcloud container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable user to set RBAC rules for Istio" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type e2-standard-2 --num-nodes 2 --labels location=$GCP_REGION --spot --enable-network-policy # to create cluster" | pv -qL 100
    gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type e2-standard-2 --num-nodes 2 --labels location=$GCP_REGION --spot --enable-network-policy 
    echo
    echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve credentials for cluster" | pv -qL 100
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable user to set RBAC rules for Istio" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ gcloud beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE # to delete cluster" | pv -qL 100
    gcloud beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE 
else
    export STEP="${STEP},2i"   
    echo
    echo "1. Create container cluster" | pv -qL 100
    echo "2. Retrieve the credentials for cluster" | pv -qL 100
    echo "3. Enable current user to set RBAC rules" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ git clone https://github.com/GoogleCloudPlatform/gke-network-policy-demo.git /tmp # to clone repo" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/manifests/hello-app/ # to install hello server" | pv -qL 100
    echo
    echo "$ kubectl logs --tail 10 \$ALLOWED_POD # to view logs for \"allowed\" client pod" | pv -qL 100
    echo
    echo "$ kubectl logs --tail 10 \$BLOCKED_POD # to tail logs for \"blocked\" client pod" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/manifests/network-policy.yaml # to restrict access with Network Policy" | pv -qL 100
    echo
    echo "$ kubectl logs --tail 10 \$ALLOWED_POD # to view logs for \"allowed\" client pod" | pv -qL 100
    echo
    echo "$ kubectl logs --tail 10 \$BLOCKED_POD # to tail logs for \"blocked\" client pod" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/manifests/network-policy-namespaced.yaml # to restrict namespaces with Network Policies" | pv -qL 100
    echo
    echo "$ kubectl logs --tail 10 \$ALLOWED_POD # to view logs for \"allowed\" client pod in default namespace" | pv -qL 100
    echo
    echo "$ kubectl logs --tail 10 \$BLOCKED_POD # to tail logs for \"blocked\" client pod in default namespace" | pv -qL 100
    echo
    echo "$ kubectl -n hello-apps apply -f \$PROJDIR/manifests/hello-app/hello-client.yaml # to deploy hello-app in hello-app namespace" | pv -qL 100
    echo
    echo "$ kubectl -n hello-apps logs --tail 10 \$ALLOWED_POD # to view logs for \"allowed\" client pod in hello-apps namespace" | pv -qL 100
    echo
    echo "$ kubectl -n hello-apps logs --tail 10 \$BLOCKED_POD # to tail logs for \"blocked\" client pod in hello-apps namespace" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1
    gcloud container clusters get-credentials $GCP_CLUSTER > /dev/null 2>&1
    echo
    rm -rf /tmp/netpolicy
    echo "$ git clone https://github.com/GoogleCloudPlatform/gke-network-policy-demo.git /tmp/netpolicy # to clone repo" | pv -qL 100
    git clone https://github.com/GoogleCloudPlatform/gke-network-policy-demo.git /tmp/netpolicy
    echo
    echo "$ cp -rf /tmp/netpolicy/manifests $PROJDIR # to copy configuration files" | pv -qL 100
    cp -rf /tmp/netpolicy/manifests $PROJDIR
    echo
    echo "$ kubectl apply -f $PROJDIR/manifests/hello-app/ # to install hello server" | pv -qL 100
    kubectl apply -f $PROJDIR/manifests/hello-app/
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export ALLOWED_POD=$(kubectl get pods -oname -l app=hello) # to set "allowed" client pod
    export BLOCKED_POD=$(kubectl get pods -oname -l app=not-hello) # to set the "blocked" client pod
    echo "$ kubectl logs --tail 10 $ALLOWED_POD # to view logs for \"allowed\" client pod" | pv -qL 100
    kubectl logs --tail 10 $ALLOWED_POD
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl logs --tail 10 $BLOCKED_POD # to tail logs for \"blocked\" client pod" | pv -qL 100
    kubectl logs --tail 10 $BLOCKED_POD
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -f $PROJDIR/manifests/network-policy.yaml # to restrict access with Network Policy" | pv -qL 100
    kubectl apply -f $PROJDIR/manifests/network-policy.yaml 
    sleep 10
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl logs --tail 10 $ALLOWED_POD # to view logs for \"allowed\" client pod" | pv -qL 100
    kubectl logs --tail 10 $ALLOWED_POD
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl logs --tail 10 $BLOCKED_POD # to tail logs for \"blocked\" client pod" | pv -qL 100
    kubectl logs --tail 10 $BLOCKED_POD
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl delete -f $PROJDIR/manifests/network-policy.yaml # to delete Network Policy" | pv -qL 100
    kubectl delete -f $PROJDIR/manifests/network-policy.yaml
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -f $PROJDIR/manifests/network-policy-namespaced.yaml # to restrict namespaces with Network Policies" | pv -qL 100
    kubectl apply -f $PROJDIR/manifests/network-policy-namespaced.yaml
    sleep 10
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl logs --tail 10 $ALLOWED_POD # to view logs for \"allowed\" client pod in default namespace" | pv -qL 100
    kubectl logs --tail 10 $ALLOWED_POD
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl logs --tail 10 $BLOCKED_POD # to tail logs for \"blocked\" client pod in default namespace" | pv -qL 100
    kubectl logs --tail 10 $BLOCKED_POD
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n hello-apps apply -f $PROJDIR/manifests/hello-app/hello-client.yaml # to deploy hello-app in hello-app namespace" | pv -qL 100
    kubectl -n hello-apps apply -f $PROJDIR/manifests/hello-app/hello-client.yaml
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export ALLOWED_POD=$(kubectl -n hello-apps get pods -oname -l app=hello) # to set "allowed" client pod
    export BLOCKED_POD=$(kubectl -n hello-apps get pods -oname -l app=not-hello) # to set the "blocked" client pod
    echo "$ kubectl -n hello-apps logs --tail 10 $ALLOWED_POD # to view logs for \"allowed\" client pod in hello-apps namespace" | pv -qL 100
    kubectl -n hello-apps logs --tail 10 $ALLOWED_POD
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl -n hello-apps logs --tail 10 $BLOCKED_POD # to tail logs for \"blocked\" client pod in hello-apps namespace" | pv -qL 100
    kubectl -n hello-apps logs --tail 10 $BLOCKED_POD
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1
    gcloud container clusters get-credentials $GCP_CLUSTER > /dev/null 2>&1
    echo
    echo "$ rm -rf $PROJDIR/manifests # to delete configuration files" | pv -qL 100
    rm -rf $PROJDIR/manifests
    echo
    echo "$ kubectl delete -f $PROJDIR/manifests/network-policy-namespaced.yaml # to delete policy" | pv -qL 100
    kubectl delete -f $PROJDIR/manifests/network-policy-namespaced.yaml
    echo
    echo "$ kubectl -n hello-apps delete -f $PROJDIR/manifests/hello-app/hello-client.yaml # to delete app" | pv -qL 100
    kubectl -n hello-apps delete -f $PROJDIR/manifests/hello-app/hello-client.yaml
else
    export STEP="${STEP},3i"   
    echo
    echo "1. Clone repository" | pv -qL 100
    echo "3. Apply deployment and services" | pv -qL 100
    echo "4. Restrict namespaces with Network Policies" | pv -qL 100
    echo "5. Explore traffic flow" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
