import { LightningElement } from 'lwc';

import logoutAuth0 from '@salesforce/apex/PortalController.logoutAuth0';
import getLoginUrl from '@salesforce/apex/PortalController.getLoginUrl';
import getUser from '@salesforce/apex/PortalController.getUser';
import getContact from '@salesforce/apex/PortalController.getContact';
import createNewUser from '@salesforce/apex/PortalController.createNewUser';


import Utils from 'c/utils';

import LOGO from '@salesforce/resourceUrl/Logo';

export default class Header extends LightningElement {

    icon = LOGO;
    isLogin = false;
    user = {};
    url;
    isSpinner = false;
    userAuth ={};
    connectedCallback() {
      
        // console.log('init header ', window.location.href);
        // console.log('init header ', window.location.href.indexOf('builder'));
        if (window.location.href.indexOf('live-preview') < 0) {
            this.isSpinner = true;
            this.init();
        }


    }

    init() {
        console.log('parameters');
        let parameters = Utils.getQueryParameters(location.search.substring(1));
        //console.log(parameters)
        if (parameters && parameters.c__code) {
            Utils.deleteCookie('WRContactId');
            let browser = Utils.getBrowserName();
            let device = Utils.getDeviceType();


            getUser({ code: parameters.c__code, browserInfo: { browser: browser, device: device } })
                .then(data => {
                   
                    this.userAuth = data;
                    console.log('getUser', data);
                    if (!!data.con && data.con.Id && !!data.con.LastName && !!data.con.FirstName) {
                        this.user = {};
                       
                        this.user = data.con;
                        this.isLogin = true;
                        Utils.setCookie('WRContactId', this.user.Id);
                        window.history.replaceState({}, '', `${window.location.pathname}`)
                        window.location.href = 'https://whiterocktech.my.site.com/portal/s/SupportTickets';
                        this.isSpinner = false;
                    } else {
                        this.isSpinner = false;
                        this.template.querySelector('[data-id="new"]').open();  
                    }
                })
                .catch(error => {
                  console.log('error' , error);
                  this.auth();
                          
                })



        } else {


            if (Utils.getCookie('WRContactId')) {
                getContact({ conId: Utils.getCookie('WRContactId') })
                    .then(data => {
                        //console.log('getContact', data);
                        if (data && data.Id) {
                            this.user = {};
                            this.user = data;
                            this.isLogin = true;
                            // this.url = `https://whiterocktech.my.site.com/portal/s/detail/${data.AccountId}`;
                            Utils.setCookie('WRContactId', this.user.Id);
                            if (window.location.href === 'https://whiterocktech.my.site.com/portal/s/') {
                                window.location.href = 'https://whiterocktech.my.site.com/portal/s/SupportTickets';
                            }
                           
                            this.isSpinner = false;
                        } else {
                            this.auth();
                        }
                    })
                    .catch(error => {
                        // console.log('error', error);
                        this.auth();
                    })

            } else {
                this.auth();
                // console.log(document.cookie);
            }

        }
    }

    auth() {
        getLoginUrl()
            .then(url => {
                window.location.href = url;
            })
            .catch(error => {
                //  console.log(error);
            })
    }

    logout() {
        logoutAuth0()
            .then(url => {
                //     console.log(' logoutAuth0 url', url);
                Utils.deleteCookie('WRContactId');
                window.location.href = url;
            })
            .catch(error => {
                //      console.log(error);
            })
    }

    createNew() {
        console.log('createNew');
        console.log('fieldsR', this.fieldsR);

        this.template.querySelector('[data-id="new"]').open();
    }


    handleSubmit(event) {
        event.preventDefault(); // stop the form from submitting
        this.isSpinner = true;
        let fields = event.detail.fields;
        console.log('fields', JSON.stringify(fields)); 
        let browser = Utils.getBrowserName();
        let device = Utils.getDeviceType();
        this.userAuth.FirstName = fields.FirstName;
        this.userAuth.LastName = fields.LastName;
        createNewUser({ browserInfo: { browser: browser, device: device }, generalData: this.userAuth})
        .then(data => {
            console.log('data', data);
            if (!!data && data.Id ) {
                this.user = {};
                
                this.user = data;
                this.isLogin = true;
                Utils.setCookie('WRContactId', this.user.Id);
                window.history.replaceState({}, '', `${window.location.pathname}`)

                window.location.href = 'https://whiterocktech.my.site.com/portal/s/SupportTickets';
                this.isSpinner = false;
            } else {
                this.isSpinner = false;
                 this.auth();
            }
        })
        .catch(error => {
            this.isSpinner = false;
            this.auth();
          console.log('error' , error);

        })
    }

    handleNewCancel(event) {
        this.template.querySelector('[data-id="new"]').close();
    }

    handleSuccess() {
   
       
        this.template.querySelector('[data-id="new"]').close(); 
    }



}