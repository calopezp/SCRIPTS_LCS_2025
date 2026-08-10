import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import validarTarjeta from '@salesforce/apex/SM_ValidarTarjetaController.validarTarjeta';
import obtenerDatosContrato from '@salesforce/apex/SM_ValidarTarjetaController.obtenerDatosContrato';

export default class ValidarTarjetaCredito extends LightningElement {
    @api recordId; // Contract ID desde Quick Action
    
    // Campos del formulario
    numeroContrato = '';
    paymentMethodName = '';
    ultimasCuatro = '';
    
    // Estado
    isLoading = false;
    showResult = false;
    validacionExitosa = false;
    
    // Resultado
    mensajeResultado = '';
    tokenParcial = '';
    paymentMethodId = '';
    ordersActualizados = 0;
    pmsEliminados = 0;
    errores = '';
    
    /**
     * Obtener datos del contrato al cargar
     */
    @wire(obtenerDatosContrato, { contractId: '$recordId' })
    wiredDatos({ error, data }) {
        if (data) {
            this.numeroContrato = data.numeroContrato || '';
            this.paymentMethodName = data.paymentMethodName || '';
        } else if (error) {
            console.error('Error obteniendo datos:', error);
        }
    }
    
    /**
     * Handlers para inputs
     */
    handleNumeroContratoChange(event) {
        this.numeroContrato = event.target.value;
    }
    
    handlePaymentMethodChange(event) {
        this.paymentMethodName = event.target.value;
    }
    
    handleUltimasCuatroChange(event) {
        this.ultimasCuatro = event.target.value;
        // Validar que solo sean números
        this.ultimasCuatro = this.ultimasCuatro.replace(/\D/g, '');
        // Limitar a 4 dígitos
        if (this.ultimasCuatro.length > 4) {
            this.ultimasCuatro = this.ultimasCuatro.substring(0, 4);
        }
    }
    
    /**
     * Validar formulario
     */
    get isFormValid() {
        return this.numeroContrato.trim() !== '' &&
               this.paymentMethodName.trim() !== '' &&
               this.ultimasCuatro.trim().length === 4;
    }
    
    /**
     * Handler para validar tarjeta
     */
    async handleValidar() {
        // Validar formulario
        if (!this.isFormValid) {
            this.showToast('Error', 'Por favor complete todos los campos correctamente', 'error');
            return;
        }
        
        this.isLoading = true;
        this.showResult = false;
        
        try {
            const result = await validarTarjeta({
                numeroContrato: this.numeroContrato,
                paymentMethodName: this.paymentMethodName,
                ultimasCuatro: this.ultimasCuatro
            });
            
            // Mostrar resultado
            this.showResult = true;
            this.validacionExitosa = result.success;
            this.mensajeResultado = result.message;
            this.tokenParcial = result.tokenParcial;
            this.paymentMethodId = result.paymentMethodId;
            this.ordersActualizados = result.ordersActualizados;
            this.pmsEliminados = result.pmsEliminados;
            this.errores = result.errores;
            
            // Toast de éxito o error
            if (result.success) {
                this.showToast('Éxito', result.message, 'success');
            } else {
                this.showToast('Error', result.message, 'error');
            }
            
        } catch (error) {
            this.showToast('Error', 'Error al validar tarjeta: ' + error.body?.message || error.message, 'error');
            console.error('Error:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    /**
     * Handler para cancelar
     */
    handleCancelar() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    
    /**
     * Handler para cerrar resultado
     */
    handleCerrar() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    
    /**
     * Mostrar toast
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
    
    /**
     * Getters para clases CSS
     */
    get resultClass() {
        return this.validacionExitosa ? 'slds-box slds-theme_success' : 'slds-box slds-theme_error';
    }
    
    get iconName() {
        return this.validacionExitosa ? 'utility:success' : 'utility:error';
    }
    
    get iconVariant() {
        return this.validacionExitosa ? 'success' : 'error';
    }
}