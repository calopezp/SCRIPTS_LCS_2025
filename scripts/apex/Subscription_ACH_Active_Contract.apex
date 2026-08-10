//CREAR SUBSCRIPTION ACH + Marcar Contrato
String contratoId = '00315195';  // ID del contrato que se va a procesar

if (String.isNotBlank(contratoId)) {
    // Consultar el contrato para obtener los datos necesarios
    Contract contrato = [SELECT Id, Name, AccountId, SM_Email_to_send_contract__c, SM_Start_date__c, SM_Monthly_offer__c, 
                                SM_Net_Monthly_offer__c, SM_Payment_Method__c, Status, SM_AC_Split_Date__c, 
                                SM_Charged_AC_Fees__c, SM_Charged_AC_Amount__c
                         FROM Contract WHERE ContractNumber = :contratoId LIMIT 1];
    
    // Verificar si se encontró el contrato
    if (contrato != null) {
        // Crear un nuevo registro SM_ACH_Order__c
        SM_ACH_Order__c newACH = new SM_ACH_Order__c();
        
        // Asignar los valores del nuevo registro basados en los datos del contrato
        newACH.SM_Contract__c = contrato.Id;
        newACH.SM_Billing_Email__c = contrato.SM_Email_to_send_contract__c;
        newACH.SM_Payment_Type__c = 'Subscription';
        newACH.SM_Payment_Frequency__c = 'Monthly';
        newACH.SM_Payment_Status__c = 'Initiated';
        newACH.SM_Fee_to_collect__c = 1;
        newACH.SM_Payment_Condition__c = 'Fixed value';
        newACH.SM_Total__c = contrato.SM_Monthly_offer__c;
        newACH.SM_Payment_Start_Date__c = contrato.SM_Start_date__c;
        newACH.SM_Payment_End_Date__c = contrato.SM_Start_date__c;
        newACH.SM_Next_Transaction_Date__c = contrato.SM_Start_date__c;
        newACH.SM_Apply_penalty__c = FALSE;
        newACH.SM_Payment_Method__c = contrato.SM_Payment_Method__c;
        newACH.SM_Id_Salesforce_LCS__c = 'Manual_' + String.valueOf(Date.today());
        newACH.SM_Migration_Date__c = DateTime.now();

		insert newACH;
        
        // Actualizacion de datos del contrato
        contrato.Status = 'Activated';
        
        // Verificar si el campo SM_AC_Split_Date__c es null y aplicar los cambios correspondientes
        if (contrato.SM_AC_Split_Date__c == null) {
                contrato.SM_Charged_AC_Fees__c = 1;  // Asignar el valor 1 al campo de tarifas
            }else
			{
				contrato.SM_Charged_AC_Fees__c = 2;
				}	
            contrato.SM_Charged_AC_Amount__c = contrato.SM_Monthly_offer__c;
			contrato.SM_AC_collected__c = true ;
			contrato.SM_Payment_Received__c = true;

                if (contrato.SM_Charged_AC_Fees__c > 0){
                    update contrato;
            }

       

        // Mostrar un mensaje de éxito
        System.debug('ACH_Order creado exitosamente y contrato actualizado a "Accepted".');
    } else {
        // Mostrar un mensaje de error si no se encontró el contrato
        System.debug('No se encontró el contrato con el ID proporcionado.');
    }
} else {
    // Mostrar un mensaje de error si no se proporcionó una ID válida de contrato
    System.debug('No se proporcionó una ID válida de contrato.');
}
