import { ShowToastEvent } from 'lightning/platformShowToastEvent';
class Utils {

    static getCookie = (name) => {
        let matches = document.cookie.match(new RegExp(
            "(?:^|; )" + name.replace(/([\.$?*|{}\(\)\[\]\\\/\+^])/g, '\\$1') + "=([^;]*)"
        ));
        return matches ? decodeURIComponent(matches[1]) : undefined;
    };

    static setCookie = (name, value, options = {}) => {
        //{secure: true, 'max-age': 3600}
        options = {
            path: '/',
            ...options
        };

        if (options.expires instanceof Date) {
            options.expires = options.expires.toUTCString();
        }

        let updatedCookie = encodeURIComponent(name) + "=" + encodeURIComponent(value);

        for (let optionKey in options) {
            updatedCookie += "; " + optionKey;
            let optionValue = options[optionKey];
            if (optionValue !== true) {
                updatedCookie += "=" + optionValue;
            }
        }

        document.cookie = updatedCookie;
    }

    static deleteCookie = (name) => {
        this.setCookie(name, "", {
            'max-age': -1
        })
    }

    static getQueryParameters = (search) => {

        var params = {};

        if (search) {
            params = JSON.parse('{"' + search.replace(/&/g, '","').replace(/=/g, '":"') + '"}', (key, value) => {
                return key === "" ? value : decodeURIComponent(value)
            });
        }

        return params;
    }

    static reduceErrors = (errors) => {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }

        return (
            errors
                // Remove null/undefined items
                .filter((error) => !!error)
                // Extract an error message
                .map((error) => {
                    // UI API read errors
                    if (Array.isArray(error.body)) {
                        return error.body.map((e) => e.message);
                    }
                    // Page level errors
                    else if (error?.body?.pageErrors && error.body.pageErrors.length > 0) {
                        return error.body.pageErrors.map((e) => e.message);
                    }
                    // Field level errors
                    else if (error?.body?.fieldErrors && Object.keys(error.body.fieldErrors).length > 0) {
                        const fieldErrors = [];
                        Object.values(error.body.fieldErrors).forEach((errorArray) => {
                            fieldErrors.push(...errorArray.map((e) => e.message));
                        });
                        return fieldErrors;
                    }
                    // UI API DML page level errors
                    else if (error?.body?.output?.errors && error.body.output.errors.length > 0) {
                        return error.body.output.errors.map((e) => e.message);
                    }
                    // UI API DML field level errors
                    else if (error?.body?.output?.fieldErrors && Object.keys(error.body.output.fieldErrors).length > 0) {
                        const fieldErrors = [];
                        Object.values(error.body.output.fieldErrors).forEach((errorArray) => {
                            fieldErrors.push(...errorArray.map((e) => e.message));
                        });
                        return fieldErrors;
                    }
                    // UI API DML, Apex and network errors
                    else if (error.body && typeof error.body.message === 'string') {
                        return error.body.message;
                    }
                    // JS errors
                    else if (typeof error.message === 'string') {
                        return error.message;
                    }
                    // Unknown error shape so try HTTP status text
                    return error.statusText;
                })
                // Flatten
                .reduce((prev, curr) => prev.concat(curr), [])
                // Remove empty strings
                .filter((message) => !!message)
        );
    };

    static dispatchToast = (ctx, options) => {
        ctx.dispatchEvent(new ShowToastEvent(options));
    };


    static getDeviceType = () => {
        const ua = navigator.userAgent;
        if (/(tablet|ipad|playbook|silk)|(android(?!.*mobi))/i.test(ua)) {
            return "tablet";
        }
        if (
            /Mobile|iP(hone|od)|Android|BlackBerry|IEMobile|Kindle|Silk-Accelerated|(hpw|web)OS|Opera M(obi|ini)/.test(
                ua
            )
        ) {
            return "mobile";
        }
        return "desktop";
    };

    static getBrowserName = () => {
        // The order matters here, and this may report false positives for unlisted browsers.
        const userAgent = navigator.userAgent;
        if (userAgent.includes("Firefox")) {
            // "Mozilla/5.0 (X11; Linux i686; rv:104.0) Gecko/20100101 Firefox/104.0"
            return "Mozilla Firefox";
        } else if (userAgent.includes("SamsungBrowser")) {
            // "Mozilla/5.0 (Linux; Android 9; SAMSUNG SM-G955F Build/PPR1.180610.011) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/9.4 Chrome/67.0.3396.87 Mobile Safari/537.36"
            return "Samsung Internet";
        } else if (userAgent.includes("Opera") || userAgent.includes("OPR")) {
            // "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_5_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36 OPR/90.0.4480.54"
            return "Opera";
        } else if (userAgent.includes("Edge")) {
            // "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36 Edge/16.16299"
            return "Microsoft Edge (Legacy)";
        } else if (userAgent.includes("Edg")) {
            // "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36 Edg/104.0.1293.70"
            return "Microsoft Edge (Chromium)";
        } else if (userAgent.includes("Chrome")) {
            // "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36"
            return "Google Chrome or Chromium";
        } else if (userAgent.includes("Safari")) {
            // "Mozilla/5.0 (iPhone; CPU iPhone OS 15_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Mobile/15E148 Safari/604.1"
            return "Apple Safari";
        } else {
            return "unknown";
        }
    };

}

export default Utils;