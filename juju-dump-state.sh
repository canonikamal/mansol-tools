#!/bin/bash

OUTDIR="juju.state.$(date +%Y%m%d%H%M%S)"
mkdir ${OUTDIR}

for CTRL in $(juju controllers --format json | jq -re '.controllers | keys[]');
do \
    for MODEL_NAME in $(juju models --controller ${CTRL} --format json | jq -r '.models[] | .name');
    do \
        MODEL_CXT="${CTRL}:${MODEL_NAME}"
        MODEL=`echo ${MODEL_NAME} | cut -d"/" -f2`
        MODEL_DIR="${OUTDIR}/${CTRL}/${MODEL}"

        echo -e "\nProcessing model: ${MODEL_CXT}"
        mkdir -p ${MODEL_DIR};

        juju export-bundle -m ${MODEL_CXT} > ${MODEL_DIR}/$(date +%F)-bundle.yaml
        echo "Dumped bundle for ${MODEL_CXT}";

        juju status -m ${MODEL_CXT} --relations > ${MODEL_DIR}/juju_status_${MODEL}.out
        juju status -m ${MODEL_CXT} --relations --format json > ${MODEL_DIR}/juju_status_${MODEL}.json
        echo "Dumped juju status for ${MODEL_CXT}";

        juju status --model ${MODEL_CXT} --relations | awk 'BEGIN{ relation=0} /^(Relation|Integration)/{relation=1}  {if (relation) print }' > ${MODEL_DIR}/relations-${MODEL}.out; \
        echo "Dumped all relations for ${MODEL_CXT}";

        juju status --model ${MODEL_CXT} | awk 'BEGIN{ saas=0; app=0} /SAAS/{saas=1} /App/{app=1} { if (saas == 1 && app == 0) print }' > ${MODEL_DIR}/saas-${MODEL}.out; 
        echo "Dumped all saas for ${MODEL_CXT}";

        SAAS=`juju status --model ${MODEL_CXT} | awk 'BEGIN{ saas=0; app=0} /SAAS/{saas=1} /App/{app=1} { if (saas == 1 && app == 0) print }' | awk '{print $1}' | grep -v SAAS`;
        for i in ${SAAS}; do grep $i ${MODEL_DIR}/relations-${MODEL}.out >> ${MODEL_DIR}/cmr-${MODEL}.out; done;
        echo "Dumped all CMRs for ${MODEL_CXT}";

        juju offers --model ${MODEL_CXT} > ${MODEL_DIR}/offers-${MODEL}.out
        echo "Dumped all offers from ${MODEL_CXT}";

        for APP in $(juju status --model ${MODEL_CXT} --format json | jq -re '.applications | keys[]') ;
        do \
            juju config --model ${MODEL_CXT} $APP > ${MODEL_DIR}/${APP}-config.yaml;
            echo "Dumped config for app ${MODEL_CXT}:${APP}";
        done;

    done
done
