import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["patentsContainer", "addressesContainer"]

  addPatent(event) {
    event.preventDefault()
    const container = document.getElementById('patents-container')
    const newId = new Date().getTime()
    const template = `
      <div class="patent-field-group flex items-center gap-2 mb-3">
        <input type="text" 
               name="entity[customs_agent_patents_attributes][${newId}][patent_number]" 
               class="flex-1 px-3 py-2 border-2 border-gray-200 focus:border-blue-500 focus:ring-blue-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900"
               placeholder="Número de patente">
        <input type="hidden" name="entity[customs_agent_patents_attributes][${newId}][_destroy]" value="false">
        <button type="button" class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors duration-150" data-action="click->entity-form#removePatent">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
          </svg>
        </button>
      </div>
    `
    container.insertAdjacentHTML('beforeend', template)
  }

  removePatent(event) {
    event.preventDefault()
    const fieldGroup = event.currentTarget.closest('.patent-field-group')
    const destroyInput = fieldGroup.querySelector('input[name*="[_destroy]"]')
    
    if (destroyInput && fieldGroup.querySelector('input[type="hidden"][name*="[id]"]')) {
      // Existing record - mark for destruction
      destroyInput.value = 'true'
      fieldGroup.style.display = 'none'
    } else {
      // New record - just remove from DOM
      fieldGroup.remove()
    }
  }

  addAddress(event) {
    event.preventDefault()
    const container = document.getElementById('addresses-container')
    const newId = new Date().getTime()
    const template = `
      <div class="address-field-group p-4 border-2 border-gray-200 rounded-lg space-y-4 relative">
        <button type="button" class="absolute top-2 right-2 p-1.5 text-red-600 hover:bg-red-50 rounded-lg transition-colors duration-150" data-action="click->entity-form#removeAddress">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
          </svg>
        </button>
        <input type="hidden" name="entity[addresses_attributes][${newId}][_destroy]" value="false">
        
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Tipo</label>
            <select name="entity[addresses_attributes][${newId}][tipo]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900">
              <option value="">Seleccionar tipo</option>
              <option value="fiscal">Fiscal</option>
              <option value="envio">Envío</option>
              <option value="almacen">Almacén</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input type="email" name="entity[addresses_attributes][${newId}][email]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="correo@ejemplo.com">
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div class="sm:col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-1">Calle</label>
            <input type="text" name="entity[addresses_attributes][${newId}][calle]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="Nombre de la calle">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Número Ext.</label>
            <input type="text" name="entity[addresses_attributes][${newId}][numero_exterior]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="123">
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Número Int.</label>
            <input type="text" name="entity[addresses_attributes][${newId}][numero_interior]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="A">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Colonia</label>
            <input type="text" name="entity[addresses_attributes][${newId}][colonia]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="Colonia">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Código Postal</label>
            <input type="text" name="entity[addresses_attributes][${newId}][codigo_postal]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="12345">
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Municipio/Delegación</label>
            <input type="text" name="entity[addresses_attributes][${newId}][municipio]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="Municipio">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Localidad</label>
            <input type="text" name="entity[addresses_attributes][${newId}][localidad]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="Localidad">
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Estado</label>
            <input type="text" name="entity[addresses_attributes][${newId}][estado]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="Estado">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">País</label>
            <input type="text" name="entity[addresses_attributes][${newId}][pais]" class="w-full px-3 py-2 border-2 border-gray-200 focus:border-teal-500 focus:ring-teal-500 rounded-lg focus:ring-2 transition-all duration-200 text-gray-900" placeholder="México" value="México">
          </div>
        </div>
      </div>
    `
    container.insertAdjacentHTML('beforeend', template)
  }

  removeAddress(event) {
    event.preventDefault()
    const fieldGroup = event.currentTarget.closest('.address-field-group')
    const destroyInput = fieldGroup.querySelector('input[name*="[_destroy]"]')
    
    if (destroyInput && fieldGroup.querySelector('input[type="hidden"][name*="[id]"]')) {
      // Existing record - mark for destruction
      destroyInput.value = 'true'
      fieldGroup.style.display = 'none'
    } else {
      // New record - just remove from DOM
      fieldGroup.remove()
    }
  }
}
