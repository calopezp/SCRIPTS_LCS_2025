/*
    Enciende/apaga el Trigger Panel "SM_PaymentTrigger" (SM_Trigger_Panel__mdt), que controla
    si el trigger SM_PaymentTrigger.trigger (SM_Payment__c) ejecuta SM_PaymentHandler
    (creacion de Late Payment Fee, actualizacion de ordenes, prorrateo a contratos dependientes,
    etc.). Util para desactivarlo temporalmente antes de una carga masiva de SM_Payment__c y
    reactivarlo justo despues.

    NO toca ningun otro Trigger Panel -- en particular no toca "SM_ChargentTransactionTGR"
    (migracion de Chargent en curso, fuera de este alcance -- ver CLAUDE.md seccion 3).

    Uso:
      1. Cambiar ENABLE abajo: false = apagar (antes de la carga), true = reactivar (despues).
      2. sf apex run -o MONEE -f scripts/apex/toggle_SM_PaymentTrigger_panel.apex
      3. Revisar el debug log: confirma el estado ANTES y DESPUES del cambio.

    IMPORTANTE: dejar el trigger apagado mas tiempo del necesario significa que ningun
    SM_Payment__c que se cree/actualice/borre mientras tanto (no solo los de tu carga) va a
    disparar SM_PaymentHandler. Reactivar tan pronto termine la carga.
*/

Boolean ENABLE = false; // false = apagar todos los eventos, true = reactivar todos

String triggerName = 'SM_PaymentTrigger';

Metadata.CustomMetadata cm = new Metadata.CustomMetadata();
cm.fullName = 'SM_Trigger_Panel.' + triggerName;
cm.label = triggerName;

List<String> fields = new List<String>{
    'SM_ProcessOnBeforeInsert__c', 'SM_ProcessOnBeforeUpdate__c', 'SM_ProcessOnBeforeDelete__c',
    'SM_ProcessOnAfterInsert__c', 'SM_ProcessOnAfterUpdate__c', 'SM_ProcessOnAfterDelete__c',
    'SM_ProcessOnUnDelete__c'
};

for (String f : fields) {
    Metadata.CustomMetadataValue v = new Metadata.CustomMetadataValue();
    v.field = f;
    v.value = ENABLE;
    cm.values.add(v);
}

Metadata.CustomMetadataValue nameVal = new Metadata.CustomMetadataValue();
nameVal.field = 'SM_TriggerName__c';
nameVal.value = triggerName;
cm.values.add(nameVal);

Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
mdContainer.addMetadata(cm);

System.debug('======================================================');
System.debug('Encolando deploy: SM_PaymentTrigger -> ' + (ENABLE ? 'ENCENDIDO (true)' : 'APAGADO (false)'));
System.debug('El resultado del deploy NO aparece en este mismo log -- es asincrono.');
System.debug('Verificar con: sf data query -o MONEE -q "SELECT SM_ProcessOnBeforeInsert__c FROM SM_Trigger_Panel__mdt WHERE SM_TriggerName__c=\'SM_PaymentTrigger\'"');
System.debug('======================================================');

Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
System.debug('Deploy job encolado, Id: ' + jobId);
