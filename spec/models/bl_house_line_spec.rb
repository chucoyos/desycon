require 'rails_helper'

RSpec.describe BlHouseLine, type: :model do
  let(:shipping_line) { create(:shipping_line) }
  let(:container) { create(:container, shipping_line: shipping_line) }
  let(:other_container) { create(:container, shipping_line: shipping_line) }

  describe 'validations' do
    subject { build(:bl_house_line) }

    it 'validates presence of blhouse' do
      subject.blhouse = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:blhouse]).to include("no puede estar en blanco")
    end

    it 'validates presence of partida' do
      subject.partida = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:partida]).to include("no puede estar en blanco")
    end

    it 'validates partida is a positive integer' do
      subject.partida = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:partida]).to include("debe ser mayor que 0")

      subject.partida = -1
      expect(subject).not_to be_valid
      expect(subject.errors[:partida]).to include("debe ser mayor que 0")

      subject.partida = 1.5
      expect(subject).not_to be_valid
      expect(subject.errors[:partida]).to include("debe ser un entero")
    end

    it 'validates presence of cantidad' do
      subject.cantidad = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:cantidad]).to include("no puede estar en blanco")
    end

    it 'validates cantidad is a positive integer' do
      subject.cantidad = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:cantidad]).to include("debe ser mayor que 0")
    end

    context 'partida uniqueness within container scope' do
      let!(:existing_bl_house_line) { create(:bl_house_line, container: container, partida: 1) }

      it 'allows same partida number in different containers' do
        new_bl_house_line = build(:bl_house_line, container: other_container, partida: 1)
        expect(new_bl_house_line).to be_valid
      end

      it 'does not allow duplicate partida within same container' do
        new_bl_house_line = build(:bl_house_line, container: container, partida: 1)
        expect(new_bl_house_line).not_to be_valid
        expect(new_bl_house_line.errors[:partida]).to include('debe ser único dentro del contenedor')
      end
    end
  end

  describe 'auto-increment partida number' do
    context 'when container is present' do
      it 'automatically assigns partida 1 for first bl_house_line in container' do
        bl_house_line = BlHouseLine.create!(
          blhouse: "BLH001",
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          container: container
        )
        expect(bl_house_line.partida).to eq(1)
      end

      it 'automatically assigns next available partida number' do
        BlHouseLine.create!(
          blhouse: "BLH001",
          partida: 1,
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          container: container
        )
        BlHouseLine.create!(
          blhouse: "BLH002",
          partida: 3,
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          container: container
        )

        bl_house_line = BlHouseLine.create!(
          blhouse: "BLH003",
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          container: container
        )
        expect(bl_house_line.partida).to eq(4)
      end

      it 'does not auto-assign if partida is already set' do
        bl_house_line = BlHouseLine.create!(
          blhouse: "BLH001",
          partida: 5,
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          container: container
        )
        expect(bl_house_line.partida).to eq(5)
      end

      it 'handles different containers independently' do
        BlHouseLine.create!(
          blhouse: "BLH001",
          partida: 1,
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          container: container
        )

        bl_house_line = BlHouseLine.create!(
          blhouse: "BLH002",
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          container: other_container
        )
        expect(bl_house_line.partida).to eq(1)
      end
    end

    context 'when container is not present' do
      it 'does not auto-assign partida number' do
        bl_house_line = BlHouseLine.new(
          blhouse: "BLH001",
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks"
        )
        bl_house_line.valid?
        expect(bl_house_line.partida).to be_nil
      end
    end
  end

  describe 'relationships' do
    it 'belongs to customs_agent' do
      association = described_class.reflect_on_association(:customs_agent)
      expect(association.macro).to eq(:belongs_to)
      expect(association.class_name).to eq('Entity')
      expect(association.options[:optional]).to be_truthy
    end

    it 'belongs to client' do
      association = described_class.reflect_on_association(:client)
      expect(association.macro).to eq(:belongs_to)
      expect(association.class_name).to eq('Entity')
      expect(association.options[:optional]).to be_truthy
    end

    it 'belongs to container' do
      association = described_class.reflect_on_association(:container)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be_truthy
    end

    it 'belongs to packaging' do
      association = described_class.reflect_on_association(:packaging)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be_truthy
    end

    it 'has many bl_house_line_status_histories' do
      association = described_class.reflect_on_association(:bl_house_line_status_histories)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe 'enums' do
    it 'defines status enum with correct values' do
      expect(described_class.statuses).to eq({
        "activo" => "activo",
        "bl_original" => "bl_original",
        "documentos_ok" => "documentos_ok",
        "despachado" => "despachado",
        "pendiente_endoso_agente_aduanal" => "pendiente_endoso_agente_aduanal",
        "pendiente_endoso_consignatario" => "pendiente_endoso_consignatario",
        "finalizado" => "finalizado",
        "instrucciones_pendientes" => "instrucciones_pendientes",
        "pendiente_pagos_locales" => "pendiente_pagos_locales",
        "listo" => "listo",
        "revalidado" => "revalidado"
      })
    end
  end

  describe '#documentos_completos?' do
    let(:bl_house_line) { create(:bl_house_line) }

    it 'returns false when no documents are attached' do
      expect(bl_house_line.documentos_completos?).to be_falsey
    end

    it 'returns false when only some documents are attached' do
      bl_house_line.bl_endosado_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      expect(bl_house_line.documentos_completos?).to be_falsey
    end

    it 'returns true when all documents are attached' do
      bl_house_line.bl_endosado_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      bl_house_line.liberacion_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      bl_house_line.bl_revalidado_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      expect(bl_house_line.documentos_completos?).to be_truthy
    end
  end
end
