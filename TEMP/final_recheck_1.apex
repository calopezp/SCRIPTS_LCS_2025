String NAMED_CRED = 'Chargebee_API';
List<String> cnIds = new List<String>{
    'CN-404',
    'CN-403',
    'CN-402',
    'CN-401',
    'CN-400',
    'CN-399',
    'CN-398',
    'CN-396',
    'CN-395',
    'CN-394',
    'CN-393',
    'CN-392',
    'CN-391',
    'CN-390',
    'CN-389',
    'CN-388',
    'CN-387',
    'CN-386',
    'CN-385',
    'CN-384',
    'CN-383',
    'CN-382',
    'CN-381',
    'CN-380',
    'CN-379',
    'CN-378',
    'CN-377',
    'CN-376',
    'CN-375',
    'CN-374',
    'CN-373',
    'CN-372',
    'CN-371',
    'CN-370',
    'CN-369',
    'CN-368',
    'CN-367',
    'CN-366',
    'CN-365',
    'CN-359',
    'CN-358',
    'CN-357',
    'CN-356',
    'CN-355',
    'CN-354',
    'CN-353',
    'CN-352',
    'CN-351',
    'CN-350',
    'CN-348',
    'CN-347',
    'CN-346',
    'CN-345',
    'CN-344',
    'CN-343',
    'CN-342',
    'CN-341',
    'CN-340',
    'CN-339',
    'CN-338',
    'CN-337',
    'CN-336',
    'CN-335',
    'CN-334',
    'CN-333',
    'CN-332',
    'CN-331',
    'CN-330',
    'CN-329',
    'CN-327',
    'CN-326',
    'CN-325',
    'CN-324',
    'CN-323',
    'CN-322',
    'CN-321',
    'CN-320',
    'CN-319',
    'CN-318',
    'CN-317'
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
