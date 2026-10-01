String NAMED_CRED = 'Chargebee_API';
List<String> cnIds = new List<String>{
    'CN-133',
    'CN-132',
    'CN-131',
    'CN-130',
    'CN-127',
    'CN-126',
    'CN-125',
    'CN-124',
    'CN-122',
    'CN-121',
    'CN-120',
    'CN-119',
    'CN-118',
    'CN-117',
    'CN-116',
    'CN-115',
    'CN-114',
    'CN-113',
    'CN-112',
    'CN-111',
    'CN-110',
    'CN-109',
    'CN-108',
    'CN-107',
    'CN-106',
    'CN-105',
    'CN-104',
    'CN-103',
    'CN-102',
    'CN-101',
    'CN-100',
    'CN-99',
    'CN-98',
    'CN-97',
    'CN-96',
    'CN-95',
    'CN-94',
    'CN-93',
    'CN-92',
    'CN-91',
    'CN-90',
    'CN-89',
    'CN-88',
    'CN-87',
    'CN-86',
    'CN-85',
    'CN-84',
    'CN-82',
    'CN-81',
    'CN-79',
    'CN-78',
    'CN-76',
    'CN-75',
    'CN-74',
    'CN-73',
    'CN-71',
    'CN-70',
    'CN-67',
    'CN-66',
    'CN-63',
    'CN-61',
    'CN-60',
    'CN-59',
    'CN-58',
    'CN-57',
    'CN-56',
    'CN-55',
    'CN-54',
    'CN-53',
    'CN-52',
    'CN-51'
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
