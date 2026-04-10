require "rails_helper"

RSpec.describe ContainersHelper, type: :helper do
  describe "#status_badge_class" do
    it "returns specific classes for the new statuses" do
      expect(helper.status_badge_class("en_espera_del_bl_fletado")).to eq("bg-sky-100 text-sky-800 border-sky-200")
      expect(helper.status_badge_class("en_proceso_de_pagos_locales")).to eq("bg-violet-100 text-violet-800 border-violet-200")
      expect(helper.status_badge_class("en_espera_del_ok_para_revalidar")).to eq("bg-yellow-100 text-yellow-800 border-yellow-200")
      expect(helper.status_badge_class("en_proceso_de_revalidacion_ante_la_ln")).to eq("bg-cyan-100 text-cyan-800 border-cyan-200")
      expect(helper.status_badge_class("mbl_revalidado_en_espera_del_atraque_de_buque")).to eq("bg-indigo-100 text-indigo-800 border-indigo-200")
      expect(helper.status_badge_class("buque_en_operaciones_en_espera_de_descarga")).to eq("bg-teal-100 text-teal-800 border-teal-200")
      expect(helper.status_badge_class("en_proceso_de_transferencia_documental")).to eq("bg-fuchsia-100 text-fuchsia-800 border-fuchsia-200")
      expect(helper.status_badge_class("detenido_por_aduana")).to eq("bg-red-100 text-red-800 border-red-200")
    end
  end

  describe "#status_icon" do
    it "returns an svg icon for each new status" do
      %w[
        en_espera_del_bl_fletado
        en_proceso_de_pagos_locales
        en_espera_del_ok_para_revalidar
        en_proceso_de_revalidacion_ante_la_ln
        mbl_revalidado_en_espera_del_atraque_de_buque
        buque_en_operaciones_en_espera_de_descarga
        en_proceso_de_transferencia_documental
        detenido_por_aduana
      ].each do |status|
        expect(helper.status_icon(status)).to include("<svg")
      end
    end
  end

  describe "#status_nombre" do
    it "returns capitalized labels for existing and new statuses" do
      expect(helper.status_nombre("en_proceso_desconsolidacion")).to eq("En Proceso de Desconsolidacion")
      expect(helper.status_nombre("fecha_tentativa_desconsolidacion")).to eq("Fecha Tentativa de Desconsolidacion")
      expect(helper.status_nombre("detenido_por_aduana")).to eq("Detenido por Aduana")
    end
  end
end
