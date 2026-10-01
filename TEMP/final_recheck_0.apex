String NAMED_CRED = 'Chargebee_API';
List<String> cnIds = new List<String>{
    'CN-486',
    'CN-485',
    'CN-484',
    'CN-483',
    'CN-482',
    'CN-481',
    'CN-480',
    'CN-479',
    'CN-478',
    'CN-477',
    'CN-476',
    'CN-475',
    'CN-474',
    'CN-473',
    'CN-472',
    'CN-471',
    'CN-470',
    'CN-469',
    'CN-468',
    'CN-467',
    'CN-466',
    'CN-465',
    'CN-464',
    'CN-463',
    'CN-462',
    'CN-461',
    'CN-460',
    'CN-459',
    'CN-458',
    'CN-457',
    'CN-456',
    'CN-455',
    'CN-454',
    'CN-453',
    'CN-452',
    'CN-451',
    'CN-450',
    'CN-449',
    'CN-448',
    'CN-447',
    'CN-446',
    'CN-445',
    'CN-444',
    'CN-443',
    'CN-442',
    'CN-441',
    'CN-440',
    'CN-439',
    'CN-438',
    'CN-437',
    'CN-436',
    'CN-435',
    'CN-434',
    'CN-433',
    'CN-432',
    'CN-431',
    'CN-430',
    'CN-429',
    'CN-428',
    'CN-427',
    'CN-426',
    'CN-425',
    'CN-424',
    'CN-423',
    'CN-422',
    'CN-421',
    'CN-420',
    'CN-419',
    'CN-418',
    'CN-417',
    'CN-416',
    'CN-415',
    'CN-414',
    'CN-413',
    'CN-412',
    'CN-409',
    'CN-408',
    'CN-407',
    'CN-406',
    'CN-405'
};
for (String cnId : cnIds) {
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CRED + '/api/v2/credit_notes/' + EncodingUtil.urlEncode(cnId, 'UTF-8'));
        req.setMethod('GET');
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> cn = (Map<String, Object>) body.get('credit_note');
            System.debug('FINALCHECK｜' + cn.get('id') + '｜' + cn.get('status') + '｜' + cn.get('reference_invoice_id') + '｜' + cn.get('reason_code'));
        } else {
            System.debug('FINALCHECK｜' + cnId + '｜ERROR');
        }
    } catch (Exception e) {
        System.debug('FINALCHECK｜' + cnId + '｜EXCEPTION');
    }
}
