require 'nokogiri'

module Edms; end
module Edms::DataLoader
  
  DATA_DIR = File.expand_path(File.dirname(__FILE__) + '/../data')
  EDMS_FILES = ["#{DATA_DIR}/2009-2010.xml"]  
  
  def load_edms
    
    log = Logger.new(STDOUT)
    
    Edm.delete_all
    Member.delete_all
    Signature.delete_all
    Session.delete_all
    
    EDMS_FILES.each do |file|
      
      # TODO: check file actually exists!
      doc = Nokogiri::XML(open(file))

      amendments = []
    
      doc.xpath('//motion').each do |motion|
        
        # make or find a Session
        session = Session.find_or_create_by_name(motion.xpath("session/text()").to_s)
        
        # create an Edm
        log << "\n#{motion.xpath("number/text()").to_s} "
        
        edm_text = motion.xpath("text/text()").to_s
        
        # to get around invalid markup
        edm_text.gsub!('&#xC3;&#xBA;', '&pound;')
        
        edm = Edm.new(:motion_xml_id => motion.xpath("id/text()").to_s,
                     :session_id => session.id,
                     :number => motion.xpath("number/text()").to_s,
                     :title => motion.xpath("title/text()").to_s,
                     :text => edm_text,
                     :signature_count => motion.xpath("signature_count/text()").to_s
                     )
        edm.save
        
        # store amendment edms in an array to deal with once we've finished loading        
        # (we can't do anything with them yet as the parent EDM may not exist at this point)  
        if edm.is_amendment?
          amendments << edm
        end
      
        # loop through the signatures, and for each one
        motion.xpath('signatures/signature').each do |signature|
          
          # make or find a Member
          member =  Member.find_or_create_by_name_and_member_xml_id(signature.xpath("mp/text()").to_s, signature.xpath("mp/@id").to_s)
        
          signature_date = signature.xpath("date/text()").to_s
          signature_type = signature.xpath("type/text()").to_s
        
          # make an appropriate sub-type of Signature and attach it to the Edm and the Session
          case signature_type
            when 'Proposed'
              new_signature = Proposer.new :date => signature_date, :member_id => member.id, :edm_id => edm.id, :session_id => session.id
              edm.proposers << new_signature
              session.proposers << new_signature
              log << 'p'
            when 'Seconded'
              new_signature = Seconder.new :date => signature_date, :member_id => member.id, :edm_id => edm.id, :session_id => session.id
              edm.seconders << new_signature
              session.seconders << new_signature
              log << '2nd'
            when 'Signed'
              new_signature = Signatory.new :date => signature_date, :member_id => member.id, :edm_id => edm.id, :session_id => session.id
              edm.signatories << new_signature
              session.signatories << new_signature
              log << 's'
            else
              raise "Unrecognised signature type: #{signature_type}"
          end
        end
      end
    
      amendments.each do |amendment|
        parts = amendment.number.split("A")
        log << parts
        amendment_number = parts.pop()
        amended_edm = parts.join("A")
        parent = Edm.find_by_number_and_session_id(amended_edm, amendment.session_id)
        
        if parent
          amendment.amendment_number = amendment_number
          amendment.parent_id = parent.id
          amendment.save!
        end
        log << "\n"
      end
    end  
  end
end
