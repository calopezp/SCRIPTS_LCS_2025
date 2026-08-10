// ┌──────────────────────────────────────────────────────────────┐
// │  activacion manual de contrato                               │
// └──────────────────────────────────────────────────────────────┘

// ------------- CONFIGURAR -------------  :)
String  contratoId          = '00316761'; // Número de contrato a activar (ContractNumber)
Integer countPayments       = 0;


if (String.isBlank(contratoId)) {
    System.debug('→❌ No se proporcionó ID de contrato.');
    return;
}

// 1️⃣  CONTRATO + CAMPOS EXTRAS (Account.Name para billing)
Contract c;
try {
    c = [
        SELECT Id, SM_Net_AC__c, SM_Charged_AC_Fees__c, SM_Charged_AC_Amount__c, SM_AC_collected__c, 
               SM_Payment_Received__c, SM_Start_date__c, SM_AC_Split_Date__c,
                Status, ContractNumber
        FROM Contract
        WHERE ContractNumber = :contratoId
        LIMIT 1
    ];
} catch (QueryException qe) {
    System.debug('→❌ Contrato no existe: ' + qe.getMessage());
    return;
}

// Consulta de Payments relacionados al contrato
List<SM_Payment__c> payments = [ 
    SELECT Id, Name, Payment_Status__c,SM_Payment_Date__c, SM_Net_Amount__c, SM_Original_Type__c, SM_Type__c
    FROM SM_Payment__c 
    WHERE SM_Contract__c = :c.Id
    ORDER BY SM_Payment_Date__c DESC
];

// Validar pagos de AC
Boolean pagoACValidado = false;
for (SM_Payment__c p : payments) {
    if ((p.SM_Original_Type__c == 'AC' || p.SM_Type__c == 'AC') && p.Payment_Status__c == 'ACCEPTED') {
        pagoACValidado = true;
        System.debug('→✅ Pago de AC validado: ' + p.Id + '(' + p.Name + ') - Monto: ' + p.SM_Net_Amount__c + ' - Fecha: ' + p.SM_Payment_Date__c);
        countPayments++;
        //break;
    }
}

System.debug('→✅ Total de pagos de AC encontrados: ' + countPayments + ' SPLIT');
 //  Activación manual de contrato, validado pago de AC
        c.Status = 'Activated';

        // Verificar si el campo SM_AC_Split_Date__c es null y aplicar los cambios correspondientes
        if (c.SM_AC_Split_Date__c == null && countPayments == 1) {
                c.SM_Charged_AC_Fees__c = 1;  // Asignar el valor 1 al campo de tarifas
            }else if (c.SM_AC_Split_Date__c != null && countPayments == 2)
                {
                    c.SM_Charged_AC_Fees__c = 2;
                }else {
                    if (countPayments > 2) 
                        {
                             System.debug('→⚠️ Se encontraron Pagos adicionales de AC (' + (countPayments - 2) + '), validar REFUND o pagos duplicados.');
                        }else if (countPayments == 0) {   
                            System.debug('→❌ No se encontraron pagos de AC válidos para el contrato.');
                            return;
                    } else {
                        System.debug('→⚠️ Se encontraron ' + countPayments + ' pagos de AC, pero no cumplen con las condiciones para asignar tarifas.');
                        return;
                    }
                }	
            c.SM_Charged_AC_Amount__c = c.SM_Net_AC__c;
			c.SM_AC_collected__c = true ;
			c.SM_Payment_Received__c = true;
            if (c.SM_Charged_AC_Fees__c > 0){
                update c;
                System.debug('→Contrato Activado y actualizado: ' + c.ContractNumber);
            }
            else {
                System.debug('→Contrato ' + c.ContractNumber + ' NO Actualizado, Validar pagos de AC');
            }

