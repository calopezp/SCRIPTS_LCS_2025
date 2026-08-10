import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import obtenerPreview from '@salesforce/apex/SM_CustomerCancellationActionController.obtenerPreview';
import marcarCustomerCancellation from '@salesforce/apex/SM_CustomerCancellationActionController.marcarCustomerCancellation';

export default class SmCustomerCancellationLwc extends LightningElement {
    @api recordId;

    isLoading = true;
    isConfirming = false;
    showResult = false;

    yaMarcado = false;
    cantidadOrdenes = 0;
    cantidadPayments = 0;
    esAdministrador = false;
    ordenes = [];

    resultadoExitoso = false;
    mensajeResultado = '';

    @wire(obtenerPreview, { contractId: '$recordId' })
    wiredPreview({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.yaMarcado = data.yaMarcado;
            this.cantidadOrdenes = data.cantidadOrdenes;
            this.cantidadPayments = data.cantidadPayments;
            this.esAdministrador = data.esAdministrador;
            this.ordenes = data.ordenes;
        } else if (error) {
            this.showToast('Error', 'No se pudo cargar la informacion del contrato: ' + this.extractError(error), 'error');
        }
    }

    get hayOrdenesAfectadas() {
        return this.cantidadOrdenes > 0;
    }

    get hayPaymentsAfectados() {
        return this.cantidadPayments > 0;
    }

    get requiereAdministrador() {
        return this.cantidadPayments > 0 && !this.esAdministrador;
    }

    get resultClass() {
        return this.resultadoExitoso ? 'slds-box slds-theme_success' : 'slds-box slds-theme_error';
    }

    async handleConfirmar() {
        this.isConfirming = true;
        try {
            const resultado = await marcarCustomerCancellation({ contractId: this.recordId });
            this.showResult = true;
            this.resultadoExitoso = resultado.success;
            this.mensajeResultado = resultado.mensaje;

            if (resultado.success) {
                this.showToast('Exito', resultado.mensaje, 'success');
                getRecordNotifyChange([{ recordId: this.recordId }]);
            } else {
                this.showToast('Error', resultado.mensaje, 'error');
            }
        } catch (error) {
            this.showToast('Error', 'Error al ejecutar la accion: ' + this.extractError(error), 'error');
        } finally {
            this.isConfirming = false;
        }
    }

    handleCancelar() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCerrar() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    extractError(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Error desconocido';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
