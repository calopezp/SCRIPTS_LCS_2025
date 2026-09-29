String NAMED_CRED = 'Chargebee_API';
List<String> cnIds = new List<String>{
    'CN-316',
    'CN-315',
    'CN-314',
    'CN-313',
    'CN-312',
    'CN-311',
    'CN-310',
    'CN-309',
    'CN-308',
    'CN-307',
    'CN-306',
    'CN-305',
    'CN-304',
    'CN-303',
    'CN-302',
    'CN-301',
    'CN-300',
    'CN-299',
    'CN-298',
    'CN-297',
    'CN-296',
    'CN-295',
    'CN-294',
    'CN-293',
    'CN-292',
    'CN-291',
    'CN-290',
    'CN-289',
    'CN-288',
    'CN-287',
    'CN-286',
    'CN-285',
    'CN-284',
    'CN-283',
    'CN-282',
    'CN-281',
    'CN-280',
    'CN-279',
    'CN-278',
    'CN-277',
    'CN-276',
    'CN-275',
    'CN-274',
    'CN-273',
    'CN-272',
    'CN-271',
    'CN-270',
    'CN-269',
    'CN-268',
    'CN-267',
    'CN-265',
    'CN-264',
    'CN-263',
    'CN-262',
    'CN-261',
    'CN-260',
    'CN-259',
    'CN-258',
    'CN-257',
    'CN-256',
    'CN-255',
    'CN-254',
    'CN-253',
    'CN-252',
    'CN-251',
    'CN-250',
    'CN-249',
    'CN-248',
    'CN-247',
    'CN-246',
    'CN-245',
    'CN-244',
    'CN-243',
    'CN-242',
    'CN-241',
    'CN-240',
    'CN-239',
    'CN-238',
    'CN-237',
    'CN-233'
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
