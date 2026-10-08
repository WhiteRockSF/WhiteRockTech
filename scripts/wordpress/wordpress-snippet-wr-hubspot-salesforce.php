<?php
/**
 * WPCode: PHP snippet, run everywhere, location Site Head (wp_head).
 * HubSpot hidden fields + Salesforce /event. WR_HS_DEBUG = false to mute logs.
 *
 * Почему не «просто найти name=client_id»: скрипт WordPress живёт в родительской странице.
 * Если форма в iframe с другого домена, родительский document не видит поля; same-origin iframe — fillDom.
 */
function wr_salesforce_hubspot_tracking() {
    ?>
    <script src="//js.hs-scripts.com/3433692.js" async defer></script>
    <script>
    try {
    (function () {
        var WR_DEBUG = window.WR_HS_DEBUG !== false;
        function log() {
            if (!WR_DEBUG) {
                return;
            }
            var a = ['[WR HubSpot]'];
            for (var i = 0; i < arguments.length; i++) {
                a.push(arguments[i]);
            }
            console.log.apply(console, a);
        }

        console.info('[WR HubSpot] script loaded');
        window.WR_HS_OK = true;

        var ipInfo = null;
        var ipPromise = null;
        var gaCache = '';
        var urlSf = 'https://whiterocktech.my.salesforce-sites.com/event/services/apexrest/event';

        function cookie(name) {
            var v = '; ' + document.cookie;
            var p = v.split('; ' + name + '=');
            if (p.length === 2) {
                return p.pop().split(';').shift() || '';
            }
            return '';
        }

        function gaFromCookie() {
            var r = cookie('_ga');
            if (!r) {
                return '';
            }
            var m = r.match(/^GA\d+\.\d+\.(.+)$/);
            return m && m[1] ? m[1] : r;
        }

        function gaId() {
            return gaCache || gaFromCookie();
        }

        function gtagIds() {
            var ids = [];
            try {
                if (window.WR_GA_MEASUREMENT_IDS && window.WR_GA_MEASUREMENT_IDS.length) {
                    window.WR_GA_MEASUREMENT_IDS.forEach(function (id) {
                        if (id) {
                            ids.push(id);
                        }
                    });
                }
            } catch (e) {}
            try {
                if (typeof monsterinsights_frontend !== 'undefined' && monsterinsights_frontend.v4_id) {
                    ids.push(monsterinsights_frontend.v4_id);
                }
            } catch (e2) {}
            return ids;
        }

        var gtagT = 0;
        function tryGtag() {
            if (gaCache || gaFromCookie()) {
                gaCache = gaCache || gaFromCookie();
                return;
            }
            if (typeof gtag !== 'function') {
                return;
            }
            var ids = gtagIds();
            if (!ids.length || Date.now() - gtagT < 2000) {
                return;
            }
            gtagT = Date.now();
            var i = 0;
            function next() {
                if (i >= ids.length) {
                    return;
                }
                var mid = ids[i++];
                try {
                    gtag('get', mid, 'client_id', function (cid) {
                        if (cid) {
                            gaCache = cid;
                        } else {
                            next();
                        }
                    });
                } catch (err) {
                    next();
                }
            }
            next();
        }

        function fetchIp() {
            return fetch('https://api.ipify.org?format=json')
                .then(function (r) {
                    return r.json();
                })
                .then(function (data) {
                    return fetch('https://pro.ip-api.com/json/' + encodeURIComponent(data.ip) + '?key=QB12I42OjgZaaS2').then(function (r) {
                        return r.json();
                    }).then(function (info) {
                        return {
                            query: info.query || data.ip || '0.0.0.0',
                            lat: info.lat || 0,
                            lon: info.lon || 0,
                            timezone: info.timezone || '',
                            country: info.country || '',
                            region: info.region || '',
                            city: info.city || ''
                        };
                    });
                })
                .catch(function () {
                    return { query: '0.0.0.0', lat: 0, lon: 0, timezone: '', country: '', region: '', city: '' };
                });
        }

        function ensureIp() {
            if (ipInfo) {
                return Promise.resolve(ipInfo);
            }
            if (!ipPromise) {
                ipPromise = fetchIp().then(function (d) {
                    ipInfo = d;
                    return d;
                });
            }
            return ipPromise;
        }

        function setInput(el, val) {
            if (!el) {
                return;
            }
            try {
                var d = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
                if (d && d.set) {
                    d.set.call(el, val);
                } else {
                    el.value = val;
                }
            } catch (e) {
                el.value = val;
            }
            try {
                el.setAttribute('value', val);
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
            } catch (e2) {}
        }

        /** Заполняет поля в этом document + в same-origin iframe (если есть). Не видит cross-origin iframe. */
        function fillDom(ga, ip) {
            function runInDoc(doc) {
                if (!doc || !doc.querySelectorAll) {
                    return;
                }
                doc.querySelectorAll('input[name="client_id"]').forEach(function (el) {
                    setInput(el, ga);
                });
                doc.querySelectorAll('input[name="ip_address"], input[name="hs_ip_address"]').forEach(function (el) {
                    setInput(el, ip);
                });
                doc.querySelectorAll('input[name="0-1/client_id"], input[name$="/client_id"]').forEach(function (el) {
                    setInput(el, ga);
                });
                doc.querySelectorAll('input[name="0-1/ip_address"], input[name$="/ip_address"]').forEach(function (el) {
                    setInput(el, ip);
                });
                doc.querySelectorAll('input[id^="client_id-"]').forEach(function (el) {
                    setInput(el, ga);
                });
                doc.querySelectorAll('input[id^="ip_address-"], input[id^="hs_ip_address-"]').forEach(function (el) {
                    setInput(el, ip);
                });
            }
            runInDoc(document);
            try {
                document.querySelectorAll('iframe').forEach(function (ifr) {
                    try {
                        var d = ifr.contentDocument || (ifr.contentWindow && ifr.contentWindow.document);
                        if (d) {
                            runInDoc(d);
                        }
                    } catch (x) {}
                });
            } catch (e2) {}
        }

        function apply() {
            tryGtag();
            var ga = gaId();
            var ip = (ipInfo && ipInfo.query) ? ipInfo.query : '0.0.0.0';
            fillDom(ga, ip);
            log('apply ga=', ga || '(empty)', 'ip=', ip);
        }

        function sendSf(type) {
            ensureIp().then(function (info) {
                fetch(urlSf, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify({
                        title: document.title,
                        clientId: gaId(),
                        url: window.location.href,
                        type: type,
                        latitude: info && info.lat ? info.lat : 0,
                        longitude: info && info.lon ? info.lon : 0,
                        timezone: info && info.timezone ? info.timezone : '',
                        country: info && info.country ? info.country : '',
                        region: info && info.region ? info.region : '',
                        city: info && info.city ? info.city : '',
                        ip: info && info.query ? info.query : '0.0.0.0'
                    })
                }).catch(function () {});
            });
        }

        var s25, s50, s75, s100;
        function scrollPct() {
            var st = document.documentElement.scrollTop || document.body.scrollTop;
            var sh = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
            var ch = document.documentElement.clientHeight || window.innerHeight;
            if (sh <= ch) {
                return 100;
            }
            return (st / (sh - ch)) * 100;
        }
        window.addEventListener('scroll', function () {
            var p = scrollPct();
            if (p > 25 && !s25) {
                s25 = true;
                sendSf('Scroll_25');
            }
            if (p > 50 && !s50) {
                s50 = true;
                sendSf('Scroll_50');
            }
            if (p > 75 && !s75) {
                s75 = true;
                sendSf('Scroll_75');
            }
            if (p > 99 && !s100) {
                s100 = true;
                sendSf('Scroll_100');
            }
        });
        window.addEventListener('load', function () {
            sendSf('Page View');
        });

        ensureIp().then(function () {
            apply();
        });
        setTimeout(function () {
            tryGtag();
            apply();
        }, 4000);

        function onHs(payload) {
            if (!payload || !payload.eventName) {
                return;
            }
            var ev = payload.eventName;
            if (ev === 'onFormReady' || ev === 'onFormDefinitionFetchSuccess') {
                apply();
                ensureIp().then(function () {
                    apply();
                });
            }
        }

        window.addEventListener('message', function (e) {
            if (e.data && e.data.type === 'hsFormCallback') {
                onHs(e.data);
            }
        }, true);
        function hsDoc(ev) {
            if (ev.detail && ev.detail.eventName) {
                onHs(ev.detail);
            }
        }
        document.addEventListener('hsFormCallback', hsDoc);
        window.addEventListener('hsFormCallback', hsDoc);

        console.info('[WR HubSpot] ready — open console on TOP page (not hs-form iframe), then: window.WR_HS_OK === true');
    })();
    } catch (e) {
        console.error('[WR HubSpot]', e);
    }
    </script>
    <?php
}
add_action('wp_head', 'wr_salesforce_hubspot_tracking', 20);
