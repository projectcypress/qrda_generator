module QrdaGenerator
  module Export
    module Cat1
      include HealthDataStandards::Export::TemplateHelper
      include HealthDataStandards::Util
      include HealthDataStandards::SVS

      def export(patient, measures, start_date, end_date)
        self.template_format = "cat1"
        self.template_directory = File.dirname(__FILE__)
        render(:template => 'show', :locals => {:patient => patient, :measures => measures, 
                                                :start_date => start_date, :end_date => end_date})
      end

      # Find all of the entries on a patient that match the given data criteria
      def entries_for_data_criteria(data_criteria, patient)
        data_criteria_oid = HQMFTemplateHelper.template_id_by_definition_and_status(data_criteria.definition, 
                                                                                    data_criteria.status || '',
                                                                                    data_criteria.negation)
        entries = patient.entries_for_oid(data_criteria_oid)
        codes = []
        vs = ValueSet.by_oid(data_criteria.code_list_id).first
        if vs
          codes = vs.code_set_map
        else
          #puts "No codes for #{data_criteria.code_list_id}"
        end
        entries.find_all { |entry| entry.is_in_code_set?(codes) }
      end

      # Given a set of measures, find the data criteria/value set pairs that are unique across all of them
      # Returns an Array of Hashes. Hashes will have a three key/value pairs. One for the data criteria oid,
      # one for the value set oid and one for the data criteria itself
      def unique_data_criteria(measures)
        all_data_criteria = measures.map {|measure| measure.all_data_criteria}.flatten
        dc_oids_and_vs_oids = all_data_criteria.map do |data_criteria|
          data_criteria_oid = HQMFTemplateHelper.template_id_by_definition_and_status(data_criteria.definition, 
                                                                            (data_criteria.status || ""),
                                                                            data_criteria.negation)
          value_set_oid = data_criteria.code_list_id
          {'data_criteria_oid' => data_criteria_oid, 'value_set_oid' => value_set_oid, 'data_criteria' => data_criteria}
        end
        dc_oids_and_vs_oids.uniq_by {|thingy| [thingy['data_criteria_oid'], thingy['value_set_oid']]}
      end

      def render_data_criteria(dc_oid, vs_oid, entries)
        html_array = entries.map do |entry|
          if dc_oid == '2.16.840.1.113883.3.560.1.1001'
            # This is a special case. This HQMF OID maps to more than one QRDA OID.
            # So we need to try to figure out what template we should use based on the
            # content of the entry
            if vs_oid == '2.16.840.1.113883.3.526.3.1279'
              # Patient Characteristic Observation Assertion template for
              # Patient Characteristic: ECOG Performance Status-Poor
              render(:partial => '2.16.840.1.113883.10.20.24.3.103', :locals => {:entry => entry,
                                                                                 :value_set_oid => vs_oid})
            else
              
            end
          else
            render(:partial => EntryTemplateResolver.partial_for(dc_oid), :locals => {:entry => entry,
                                                                                      :value_set_oid => vs_oid})
          end
        end
        html_array.join("\n")
      end

      def render_patient_data(patient, measures)
        udcs = unique_data_criteria(measures)
        data_criteria_html = udcs.map do |udc|
          entries = entries_for_data_criteria(udc['data_criteria'], patient)
          render_data_criteria(udc['data_criteria_oid'], udc['value_set_oid'], entries)          
        end
        data_criteria_html.compact.join("\n")
      end

      extend self
    end
  end
end

HealthDataStandards::Export::RenderingContext.class_eval do
  include QrdaGenerator::Export::Cat1
end