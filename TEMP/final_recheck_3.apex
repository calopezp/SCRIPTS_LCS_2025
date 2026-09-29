String NAMED_CRED = 'Chargebee_API';
List<String> cnIds = new List<String>{
    'CN-232',
    'CN-231',
    'CN-230',
    'CN-229',
    'CN-228',
    'CN-227',
    'CN-226',
    'CN-225',
    'CN-224',
    'CN-223',
    'CN-220',
    'CN-219',
    'CN-218',
    'CN-215',
    'CN-214',
    'CN-213',
    'CN-212',
    'CN-211',
    'CN-210',
    'CN-209',
    'CN-208',
    'CN-206',
    'CN-205',
    'CN-204',
    'CN-203',
    'CN-202',
    'CN-201',
    'CN-200',
    'CN-199',
    'CN-198',
    'CN-197',
    'CN-195',
    'CN-194',
    'CN-193',
    'CN-191',
    'CN-190',
    'CN-189',
    'CN-188',
    'CN-187',
    'CN-186',
    'CN-184',
    'CN-183',
    'CN-182',
    'CN-180',
    'CN-179',
    'CN-178',
    'CN-177',
    'CN-176',
    'CN-175',
    'CN-174',
    'CN-173',
    'CN-172',
    'CN-171',
    'CN-170',
    'CN-169',
    'CN-168',
    'CN-167',
    'CN-166',
    'CN-165',
    'CN-164',
    'CN-163',
    'CN-162',
    'CN-161',
    'CN-160',
    'CN-159',
    'CN-158',
    'CN-157',
    'CN-156',
    'CN-154',
    'CN-153',
    'CN-152',
    'CN-151',
    'CN-150',
    'CN-149',
    'CN-143',
    'CN-142',
    'CN-137',
    'CN-136',
    'CN-135',
    'CN-134'
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
