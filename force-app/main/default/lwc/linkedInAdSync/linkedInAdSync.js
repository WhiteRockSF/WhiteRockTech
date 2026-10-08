import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getSettings from '@salesforce/apex/LinkedInAdMetricsController.getSettings';
import saveSettings from '@salesforce/apex/LinkedInAdMetricsController.saveSettings';
import importCsv from '@salesforce/apex/LinkedInAdMetricsController.importCsv';
import fetchFromLinkedIn from '@salesforce/apex/LinkedInAdMetricsController.fetchFromLinkedIn';
import startHubSpotSyncBatch from '@salesforce/apex/LinkedInAdMetricsController.startHubSpotSyncBatch';
import getRecentMetrics from '@salesforce/apex/LinkedInAdMetricsController.getRecentMetrics';
import testLinkedInConnection from '@salesforce/apex/LinkedInAdMetricsController.testLinkedInConnection';
import refreshLinkedInToken from '@salesforce/apex/LinkedInAdMetricsController.refreshLinkedInToken';
import testHubSpotConnection from '@salesforce/apex/LinkedInAdMetricsController.testHubSpotConnection';
import scheduleDailySync from '@salesforce/apex/LinkedInAdMetricsController.scheduleDailySync';
import stopDailySync from '@salesforce/apex/LinkedInAdMetricsController.stopDailySync';
import getBatchStatus from '@salesforce/apex/LinkedInAdMetricsController.getBatchStatus';

const METRICS_COLUMNS = [
    { label: 'Company', fieldName: 'companyName', type: 'text' },
    { label: 'Impressions', fieldName: 'impressions', type: 'number' },
    { label: 'Clicks', fieldName: 'clicks', type: 'number' },
    { label: 'Conversions', fieldName: 'conversions', type: 'number' },
    { label: 'HubSpot Status', fieldName: 'syncStatus', type: 'text' },
    { label: 'HubSpot Error', fieldName: 'syncError', type: 'text', wrapText: true },
    { label: 'Source', fieldName: 'source', type: 'text' }
];

export default class LinkedInAdSync extends LightningElement {
  @track campaignName = '';
  @track linkedInCampaignId = '';
  @track reportStart;
  @track reportEnd;
  @track settings = {};
  @track metrics = [];
  @track isBusy = false;
  @track batchJobId;
  @track batchStatus;
  @track batchPolling = false;

  columns = METRICS_COLUMNS;
  wiredMetricsResult;
  wiredSettingsResult;
  batchPollInterval;

  @wire(getSettings)
  wiredSettings(result) {
    this.wiredSettingsResult = result;
    if (result.data) {
      this.settings = { ...result.data };
      // Restore last used campaign fields (do not wipe if user already typed)
      if (!this.campaignName && result.data.defaultCampaignName) {
        this.campaignName = result.data.defaultCampaignName;
      }
      if (!this.linkedInCampaignId && result.data.defaultLinkedInCampaignId) {
        this.linkedInCampaignId = result.data.defaultLinkedInCampaignId;
      }
      if (!this.reportStart && result.data.defaultReportStart) {
        this.reportStart = result.data.defaultReportStart;
      }
      if (!this.reportEnd && result.data.defaultReportEnd) {
        this.reportEnd = result.data.defaultReportEnd;
      }
    } else if (result.error) {
      this.showError(result.error);
    }
  }

  @wire(getRecentMetrics, { campaignName: '$campaignName', rowLimit: 100 })
  wiredMetrics(result) {
    this.wiredMetricsResult = result;
    if (result.data) {
      this.metrics = result.data;
    } else if (result.error) {
      this.showError(result.error);
    }
  }

  handleCampaignNameChange(event) {
    this.campaignName = event.detail.value;
  }

  handleCampaignIdChange(event) {
    this.linkedInCampaignId = event.detail.value;
  }

  handleCampaignDefaultsBlur() {
    this.persistSyncDefaults().catch(() => {
      /* ignore background save errors */
    });
  }

  async handleSaveSyncDefaults() {
    this.isBusy = true;
    try {
      const endEmpty = !(this.reportEnd != null && String(this.reportEnd).trim());
      await this.persistSyncDefaults();
      this.showToast(
        'Saved',
        endEmpty
          ? 'Saved. Report End is empty → fetch will use today.'
          : 'Campaign and report dates saved.',
        'success'
      );
      if (this.wiredSettingsResult) {
        await refreshApex(this.wiredSettingsResult);
      }
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  /** Persist Sync-tab fields so they survive page reload. Empty Report End clears saved date (= use today). */
  async persistSyncDefaults() {
    const start = this.reportStart != null ? String(this.reportStart).trim() : '';
    const end = this.reportEnd != null ? String(this.reportEnd).trim() : '';
    const payload = {
      clearDefaultReportStart: !start,
      clearDefaultReportEnd: !end
    };
    if (this.campaignName) {
      payload.defaultCampaignName = String(this.campaignName).trim();
    }
    if (this.linkedInCampaignId) {
      payload.defaultLinkedInCampaignId = String(this.linkedInCampaignId).trim();
    }
    if (start) {
      payload.defaultReportStart = start;
    }
    if (end) {
      payload.defaultReportEnd = end;
    }
    if (
      !payload.defaultCampaignName &&
      !payload.defaultLinkedInCampaignId &&
      !payload.defaultReportStart &&
      !payload.defaultReportEnd &&
      !payload.clearDefaultReportStart &&
      !payload.clearDefaultReportEnd
    ) {
      return;
    }
    await saveSettings({ settingsJson: JSON.stringify(payload) });
    this.settings = {
      ...this.settings,
      defaultReportStart: start || null,
      defaultReportEnd: end || null,
      ...(payload.defaultCampaignName ? { defaultCampaignName: payload.defaultCampaignName } : {}),
      ...(payload.defaultLinkedInCampaignId
        ? { defaultLinkedInCampaignId: payload.defaultLinkedInCampaignId }
        : {})
    };
  }

  handleReportStartChange(event) {
    this.reportStart = event.detail.value;
  }

  handleReportEndChange(event) {
    this.reportEnd = event.detail.value;
  }

  /** YYYY-MM-DD in local browser date (for lightning-input type=date). */
  todayIso() {
    const d = new Date();
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  /** Empty Report End → today. */
  resolveReportEnd() {
    const v = this.reportEnd != null ? String(this.reportEnd).trim() : '';
    return v || this.todayIso();
  }

  handleSettingsChange(event) {
    const field = event.target.dataset.field;
    if (field) {
      this.settings = { ...this.settings, [field]: event.detail.value };
    }
  }

  /** Read current input values (password fields may not have fired change yet). */
  collectSettingsFromForm() {
    const settings = { ...(this.settings || {}) };
    this.template.querySelectorAll('lightning-input[data-field]').forEach((el) => {
      const field = el.dataset.field;
      if (!field) {
        return;
      }
      if (el.type === 'checkbox') {
        settings[field] = el.checked === true;
      } else {
        const val = el.value;
        if (val !== undefined && val !== null && String(val).trim() !== '') {
          if (field === 'hubSpotBatchSize' || field === 'autoSyncLookbackDays' || field === 'scheduleHour') {
            const num = Number(val);
            settings[field] = Number.isFinite(num) ? num : val;
          } else {
            settings[field] = String(val).trim();
          }
        }
      }
    });
    return settings;
  }

  async persistSettings() {
    const settings = this.collectSettingsFromForm();
    if (
      settings.linkedInAccessToken &&
      String(settings.linkedInAccessToken).length > 255
    ) {
      settings.useLinkedInNamedCredential = true;
    }
    this.settings = settings;
    // Pass JSON string — Aura DTO deserialization from LWC was arriving empty in Apex
    await saveSettings({ settingsJson: JSON.stringify(settings) });
    if (this.wiredSettingsResult) {
      await refreshApex(this.wiredSettingsResult);
    }
  }

  handleSettingsCheckbox(event) {
    const field = event.target.dataset.field;
    if (field) {
      this.settings = { ...this.settings, [field]: event.detail.checked };
    }
  }

  async handleFileChange(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) {
      return;
    }
    if (!this.campaignName) {
      this.showToast('Campaign Name required', 'Enter the LinkedIn campaign name before importing.', 'warning');
      return;
    }
    this.isBusy = true;
    try {
      const csvContent = await this.readFileAsText(file);
      const result = await importCsv({
        csvContent,
        campaignName: this.campaignName,
        linkedInCampaignId: this.linkedInCampaignId
      });
      this.showToast('CSV imported', result.message, 'success');
      await this.persistSyncDefaults();
      await refreshApex(this.wiredMetricsResult);
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
      event.target.value = null;
    }
  }

  readFileAsText(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(reader.error);
      reader.readAsText(file);
    });
  }

  async handleFetchLinkedIn() {
    if (!this.campaignName) {
      this.showToast('Campaign Name required', 'Enter the campaign name from Campaign Manager.', 'warning');
      return;
    }
    this.isBusy = true;
    try {
      const reportEnd = this.resolveReportEnd();
      // Do not write "today" into the field — empty means "always today"
      const result = await fetchFromLinkedIn({
        campaignName: this.campaignName,
        linkedInCampaignId: this.linkedInCampaignId,
        reportStart: this.reportStart || null,
        reportEnd
      });
      const rows = result?.rowCount != null ? result.rowCount : 0;
      const msg =
        result?.message ||
        `Received ${rows} company rows from LinkedIn.`;
      const variant = rows === 0 ? 'warning' : 'success';
      this.showToast(
        rows === 0 ? 'LinkedIn: 0 rows' : `LinkedIn: ${rows} rows`,
        msg,
        variant
      );
      await this.persistSyncDefaults();
      await refreshApex(this.wiredMetricsResult);
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  async handleStartHubSpotBatch() {
    this.isBusy = true;
    try {
      this.batchJobId = await startHubSpotSyncBatch({
        campaignName: this.campaignName || null
      });
      this.showToast(
        'HubSpot sync started',
        'Batch job Id: ' + this.batchJobId + '. Missing companies will be created in HubSpot.',
        'success'
      );
      this.pollBatchStatus();
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  pollBatchStatus() {
    if (!this.batchJobId) {
      return;
    }
    if (this.batchPollInterval) {
      window.clearInterval(this.batchPollInterval);
    }
    this.batchPolling = true;
    this.batchPollInterval = window.setInterval(async () => {
      try {
        const status = await getBatchStatus({
          jobId: this.batchJobId,
          campaignName: this.campaignName || null
        });
        this.batchStatus = status;
        if (this.wiredMetricsResult) {
          await refreshApex(this.wiredMetricsResult);
        }
        if (
          status &&
          (status.status === 'Completed' || status.status === 'Failed' || status.status === 'Aborted')
        ) {
          window.clearInterval(this.batchPollInterval);
          this.batchPollInterval = null;
          this.batchPolling = false;
          await refreshApex(this.wiredMetricsResult);
          this.showToast(
            'Batch finished',
            status.status +
              ` — synced ${status.syncedCount || 0}, pending ${status.pendingCount || 0}, failed ${status.failedCount || 0}`,
            status.status === 'Completed' ? 'success' : 'error'
          );
        }
      } catch (e) {
        window.clearInterval(this.batchPollInterval);
        this.batchPollInterval = null;
        this.batchPolling = false;
      }
    }, 2500);
  }

  disconnectedCallback() {
    if (this.batchPollInterval) {
      window.clearInterval(this.batchPollInterval);
      this.batchPollInterval = null;
    }
  }

  async handleSaveSettings() {
    this.isBusy = true;
    try {
      await this.persistSettings();
      this.showToast('Settings saved', 'Integration settings updated.', 'success');
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  async handleTestLinkedIn() {
    this.isBusy = true;
    try {
      // Do not save before test — empty LWC payload was wiping URN / Campaign Id.
      const msg = await testLinkedInConnection();
      this.showToast('LinkedIn', msg, msg.startsWith('SUCCESS') ? 'success' : 'error');
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  async handleRefreshLinkedInToken() {
    this.isBusy = true;
    try {
      const msg = await refreshLinkedInToken();
      this.showToast('LinkedIn Refresh', msg, msg.startsWith('SUCCESS') ? 'success' : 'error');
      if (msg.startsWith('SUCCESS') && this.wiredSettingsResult) {
        await refreshApex(this.wiredSettingsResult);
      }
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  async handleTestHubSpot() {
    this.isBusy = true;
    try {
      const msg = await testHubSpotConnection();
      this.showToast('HubSpot', msg, msg.startsWith('SUCCESS') ? 'success' : 'error');
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  async handleScheduleDaily() {
    this.isBusy = true;
    try {
      await this.persistSettings();
      const hour = Number(this.settings.scheduleHour);
      const msg = await scheduleDailySync({
        hour: Number.isFinite(hour) ? hour : 6
      });
      this.showToast('Schedule', msg, msg.startsWith('SUCCESS') ? 'success' : 'error');
      if (this.wiredSettingsResult) {
        await refreshApex(this.wiredSettingsResult);
      }
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  async handleStopDaily() {
    this.isBusy = true;
    try {
      const msg = await stopDailySync();
      this.showToast('Schedule', msg, msg.startsWith('SUCCESS') ? 'success' : 'error');
      if (this.wiredSettingsResult) {
        await refreshApex(this.wiredSettingsResult);
      }
    } catch (e) {
      this.showError(e);
    } finally {
      this.isBusy = false;
    }
  }

  get batchStatusLabel() {
    if (!this.batchStatus || !this.batchStatus.status) {
      return '';
    }
    const chunks = this.batchStatus.total != null ? `${this.batchStatus.processed}/${this.batchStatus.total}` : '';
    const counts = `synced ${this.batchStatus.syncedCount || 0} · pending ${this.batchStatus.pendingCount || 0} · failed ${this.batchStatus.failedCount || 0}`;
    return chunks
      ? `${this.batchStatus.status} (${chunks}) — ${counts}`
      : `${this.batchStatus.status} — ${counts}`;
  }

  get hasRecentCompanies() {
    return this.batchStatus?.recentCompanies?.length > 0;
  }

  get hasPendingCompanies() {
    return this.batchStatus?.pendingCompanies?.length > 0;
  }

  get recentCompaniesText() {
    return (this.batchStatus?.recentCompanies || []).join(', ');
  }

  get pendingCompaniesText() {
    const list = this.batchStatus?.pendingCompanies || [];
    if (!list.length) {
      return '';
    }
    const more =
      (this.batchStatus.pendingCount || 0) > list.length
        ? ` (+${(this.batchStatus.pendingCount || 0) - list.length} more)`
        : '';
    return list.join(', ') + more;
  }

  get showBatchProgress() {
    return !!(this.batchPolling || this.batchStatusLabel);
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  showError(error) {
    const message = error?.body?.message || error?.message || String(error);
    this.showToast('Error', message, 'error');
  }
}