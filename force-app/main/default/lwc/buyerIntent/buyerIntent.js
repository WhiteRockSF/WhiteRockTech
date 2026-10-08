import { LightningElement, track } from 'lwc';
import getCompanyIntents from '@salesforce/apex/BuyerIntentController.getCompanyIntents';
import testHubSpotConnection from '@salesforce/apex/BuyerIntentController.testHubSpotConnection';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BuyerIntent extends LightningElement {
    @track companies = [];
    @track filteredCompanies = [];
    @track paginatedCompanies = [];
    @track isLoading = true;
    @track error;
    @track searchTerm = '';
    @track selectedFilter = 'all';
    @track timeFrame = 'all';
    @track sortBy = 'pageViews';
    @track sortDirection = 'desc';
    
    // Pagination
    @track currentPage = 1;
    @track pageSize = 25;
    @track totalPages = 1;
    
    refreshInterval;

    columns = [
        { 
            label: 'Company Name', 
            fieldName: 'recordLink', 
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'companyName' },
                target: '_self',
                tooltip: { fieldName: 'recordType' }
            },
            sortable: true
        },
        { label: 'Industry', fieldName: 'industry', type: 'text', sortable: true },
        { label: 'Country', fieldName: 'country', type: 'text', sortable: true },
        { label: 'Employees', fieldName: 'employeeRange', type: 'text', sortable: true },
        { label: 'Page Views', fieldName: 'pageViews', type: 'number', sortable: true },
        { label: 'Unique Visitors', fieldName: 'uniqueVisitors', type: 'number', sortable: true },
        { label: 'Last Visit', fieldName: 'lastVisit', type: 'date', sortable: true }
    ];

    get filterOptions() {
        return [
            { label: 'All Companies', value: 'all' },
            { label: 'High Intent (10+ views)', value: 'high' },
            { label: 'Medium Intent (5-9 views)', value: 'medium' },
            { label: 'Low Intent (1-4 views)', value: 'low' }
        ];
    }

    get timeFrameOptions() {
        return [
            { label: 'All time', value: 'all' },
            { label: 'Today', value: 'today' },
            { label: 'Yesterday', value: 'yesterday' },
            { label: 'This week', value: 'thisWeek' },
            { label: 'Last week', value: 'lastWeek' },
            { label: 'Last 7 days', value: 'last7' },
            { label: 'Last 14 days', value: 'last14' },
            { label: 'Last 30 days', value: 'last30' },
            { label: 'Last 90 days', value: 'last90' },
            { label: 'This month', value: 'thisMonth' },
            { label: 'Last month', value: 'lastMonth' }
        ];
    }

    get totalCompanies() {
        return this.filteredCompanies.length;
    }

    get totalPageViews() {
        return this.filteredCompanies.reduce((sum, company) => sum + (company.pageViews || 0), 0);
    }

    get totalUniqueVisitors() {
        return this.filteredCompanies.reduce((sum, company) => sum + (company.uniqueVisitors || 0), 0);
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get disablePrevious() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    get pageInfo() {
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalCompanies);
        return `${start}-${end} of ${this.totalCompanies}`;
    }

    connectedCallback() {
        this.loadData();
        this.startAutoRefresh();
    }

    disconnectedCallback() {
        this.stopAutoRefresh();
    }

    loadData() {
        this.isLoading = true;
        getCompanyIntents()
            .then(result => {
                console.log('Companies received:', result);
                // Add record links
                this.companies = result.map(company => {
                    return {
                        ...company,
                        recordLink: company.salesforceId ? `/${company.salesforceId}` : company.companyUrl
                    };
                });
                this.applyFilters();
                this.isLoading = false;
                this.error = undefined;
            })
            .catch(error => {
                console.error('Error loading companies:', error);
                this.error = error;
                this.isLoading = false;
                let errorMessage = 'Unknown error';
                if (error.body && error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.message) {
                    errorMessage = error.message;
                }
                this.showToast('Error', 'Error loading data: ' + errorMessage, 'error');
            });
    }

    handleRefresh() {
        this.loadData();
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleFilterChange(event) {
        this.selectedFilter = event.detail.value;
        this.applyFilters();
    }

    handleTimeFrameChange(event) {
        this.timeFrame = event.detail.value;
        this.applyFilters();
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortBy = fieldName;
        this.sortDirection = sortDirection;
        this.sortData();
    }

    applyFilters() {
        let filtered = [...this.companies];

        // Фильтр по поиску
        if (this.searchTerm) {
            filtered = filtered.filter(company => {
                return (
                    (company.companyName && company.companyName.toLowerCase().includes(this.searchTerm)) ||
                    (company.industry && company.industry.toLowerCase().includes(this.searchTerm)) ||
                    (company.country && company.country.toLowerCase().includes(this.searchTerm))
                );
            });
        }

        // Фильтр по времени последнего визита
        if (this.timeFrame !== 'all') {
            const now = new Date();
            const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            
            console.log('Filtering by timeFrame:', this.timeFrame);
            console.log('Today date:', today);
            console.log('Companies before time filter:', filtered.length);
            
            filtered = filtered.filter(company => {
                if (!company.lastVisit) return false;
                
                const visitDate = new Date(company.lastVisit);
                console.log('Company:', company.companyName, 'Last Visit:', visitDate);
                
                let result = false;
                
                switch (this.timeFrame) {
                    case 'today':
                        result = visitDate >= today;
                        console.log('  Today check:', visitDate, '>=', today, '=', result);
                        return result;
                    
                    case 'yesterday':
                        const yesterday = new Date(today);
                        yesterday.setDate(yesterday.getDate() - 1);
                        result = visitDate >= yesterday && visitDate < today;
                        return result;
                    
                    case 'thisWeek':
                        const startOfWeek = new Date(today);
                        startOfWeek.setDate(today.getDate() - today.getDay());
                        return visitDate >= startOfWeek;
                    
                    case 'lastWeek':
                        const startOfLastWeek = new Date(today);
                        startOfLastWeek.setDate(today.getDate() - today.getDay() - 7);
                        const endOfLastWeek = new Date(today);
                        endOfLastWeek.setDate(today.getDate() - today.getDay() - 1);
                        endOfLastWeek.setHours(23, 59, 59, 999);
                        return visitDate >= startOfLastWeek && visitDate <= endOfLastWeek;
                    
                    case 'last7':
                        const last7 = new Date(today);
                        last7.setDate(today.getDate() - 7);
                        return visitDate >= last7;
                    
                    case 'last14':
                        const last14 = new Date(today);
                        last14.setDate(today.getDate() - 14);
                        return visitDate >= last14;
                    
                    case 'last30':
                        const last30 = new Date(today);
                        last30.setDate(today.getDate() - 30);
                        return visitDate >= last30;
                    
                    case 'last90':
                        const last90 = new Date(today);
                        last90.setDate(today.getDate() - 90);
                        return visitDate >= last90;
                    
                    case 'thisMonth':
                        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
                        return visitDate >= startOfMonth;
                    
                    case 'lastMonth':
                        const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
                        const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);
                        return visitDate >= startOfLastMonth && visitDate <= endOfLastMonth;
                    
                    default:
                        return true;
                }
            });
        }

        // Фильтр по уровню интереса
        if (this.selectedFilter !== 'all') {
            filtered = filtered.filter(company => {
                const views = company.pageViews || 0;
                switch (this.selectedFilter) {
                    case 'high':
                        return views >= 10;
                    case 'medium':
                        return views >= 5 && views < 10;
                    case 'low':
                        return views >= 1 && views < 5;
                    default:
                        return true;
                }
            });
        }

        this.filteredCompanies = filtered;
        this.sortData();
        this.updatePagination();
    }

    updatePagination() {
        this.totalPages = Math.ceil(this.filteredCompanies.length / this.pageSize);
        if (this.currentPage > this.totalPages) {
            this.currentPage = 1;
        }
        this.paginateData();
    }

    paginateData() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.paginatedCompanies = this.filteredCompanies.slice(start, end);
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.paginateData();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.paginateData();
        }
    }

    handleFirst() {
        this.currentPage = 1;
        this.paginateData();
    }

    handleLast() {
        this.currentPage = this.totalPages;
        this.paginateData();
    }

    sortData() {
        const data = [...this.filteredCompanies];
        const reverse = this.sortDirection === 'asc' ? 1 : -1;
        
        data.sort((a, b) => {
            let aVal = a[this.sortBy] || '';
            let bVal = b[this.sortBy] || '';
            
            if (typeof aVal === 'string') {
                return reverse * aVal.localeCompare(bVal);
            }
            return reverse * (aVal - bVal);
        });
        
        this.filteredCompanies = data;
        this.paginateData();
    }

    startAutoRefresh() {
        this.refreshInterval = setInterval(() => {
            this.handleRefresh();
        }, 300000);
    }

    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
    }

    handleTestConnection() {
        this.isLoading = true;
        testHubSpotConnection()
            .then(result => {
                if (result.startsWith('SUCCESS')) {
                    this.showToast('Success', result, 'success');
                } else {
                    this.showToast('Connection Test', result, 'warning');
                }
            })
            .catch(error => {
                this.showToast('Error', 'Connection test failed: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }
}