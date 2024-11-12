'use strict';

exports.handler = (event, context, callback) => {
    const request = event.Records[0].cf.request;
    const releaseVersion = Array.isArray(request.headers['x-release-version']) ? request.headers['x-release-version'][0].value : 'v3.0.0';

    let domainName = 'rpp-site-wise-beta.s3-website-us-east-1.amazonaws.com';

    if (releaseVersion === 'v3.1.0') {
        domainName = 'rpp-site-wise-2024.4.744-0.s3-website-us-east-1.amazonaws.com';
    } else if (releaseVersion === 'beta') {
        domainName = 'rpp-site-wise-beta.s3-website-us-east-1.amazonaws.com';
    } else if (releaseVersion === 'v3.0.0') {
        domainName = 'rpp-site-wise-2024.3.743-0.s3-website-us-east-1.amazonaws.com';
    }

    console.log('domainName: ', domainName);

    /* Set custom origin fields*/
    request.origin = {
        custom: {
            domainName: domainName,
            port: 80,
            protocol: 'http',
            path: '',
            sslProtocols: ['TLSv1.2'], // Only use TLSv1.2 or higher
            readTimeout: 5,
            keepaliveTimeout: 5,
            customHeaders: {}
        }
    };
    request.headers['host'] = [{ key: 'host', value: domainName}];

    callback(null, request);
};
