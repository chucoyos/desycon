class ChangeVoyageDatesToDatetimes < ActiveRecord::Migration[8.1]
  def up
    change_column :voyages, :ata, :datetime, using: "ata::timestamp"
    change_column :voyages, :eta, :datetime, using: "eta::timestamp"
    change_column :voyages, :inicio_operacion, :datetime, using: "inicio_operacion::timestamp"
    change_column :voyages, :fin_operacion, :datetime, using: "fin_operacion::timestamp"
  end

  def down
    change_column :voyages, :ata, :date, using: "ata::date"
    change_column :voyages, :eta, :date, using: "eta::date"
    change_column :voyages, :inicio_operacion, :date, using: "inicio_operacion::date"
    change_column :voyages, :fin_operacion, :date, using: "fin_operacion::date"
  end
end
