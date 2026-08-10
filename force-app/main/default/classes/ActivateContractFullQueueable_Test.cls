@IsTest
public class ActivateContractFullQueueable_Test {

    @IsTest
    static void testQueueableExecution() {

        // 1️⃣ Crear contrato de prueba
        Contract c = new Contract(
            ContractNumber = '00100000',
            Status = 'Payment Process',
            SM_Net_AC__c = 100,
            SM_AC_collected__c = false,
            SM_Payment_Received__c = false
        );
        insert c;

        // 2️⃣ Crear pago AC válido
        SM_Payment__c p = new SM_Payment__c(
            //Name = 'Pago AC Test',
            SM_Contract__c = c.Id,
            Payment_Status__c = 'ACCEPTED',
            SM_Original_Type__c = 'AC',
            SM_Type__c = 'AC',
            SM_Net_Amount__c = 100,
            SM_Payment_Date__c = Date.today()
        );
        insert p;

        // 3️⃣ Crear ACH Order asociado
        SM_ACH_Order__c ach = new SM_ACH_Order__c(
            //Name = 'ACH Test',
            SM_Contract__c = c.Id,
            SM_Payment_Status__c = 'pending'
        );
        insert ach;

        // 4️⃣ Crear Payment asociado al ACH
        SM_Payment__c pagoAch = new SM_Payment__c(
            Name = 'Pago ACH Test',
            SM_ACH_Order__c = ach.Id,
            SM_Contract__c = c.Id,
            SM_Check_Collection_Status__c = 'NOT_COLLECTED'
        );
        insert pagoAch;

        // 5️⃣ Crear TC Order asociado
        ChargentOrders__ChargentOrder__c tc = new ChargentOrders__ChargentOrder__c(
            Name = 'TC Test',
            Contract__c = c.Id,
            ChargentOrders__Payment_Status__c = 'Pending'
        );
        insert tc;

        // 6️⃣ Ejecutar el Queueable
        Test.startTest();
        System.enqueueJob(new ActivateContractFullQueueable('TEST-001'));
        Test.stopTest();

        // 7️⃣ Validaciones
        Contract updatedC = [SELECT Status, SM_AC_collected__c, SM_Payment_Received__c
                             FROM Contract WHERE Id = :c.Id];

        System.assertEquals('Activated', updatedC.Status);
        System.assertEquals(true, updatedC.SM_AC_collected__c);
        System.assertEquals(true, updatedC.SM_Payment_Received__c);

        SM_ACH_Order__c updatedAch = [SELECT SM_Payment_Status__c FROM SM_ACH_Order__c WHERE Id = :ach.Id];
        System.assertEquals('Canceled', updatedAch.SM_Payment_Status__c);

        ChargentOrders__ChargentOrder__c updatedTc = [
            SELECT ChargentOrders__Payment_Status__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Id = :tc.Id
        ];
        System.assertEquals('X CANCELED', updatedTc.ChargentOrders__Payment_Status__c);
    }
}