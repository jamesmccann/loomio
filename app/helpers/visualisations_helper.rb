module VisualisationsHelper

  def gravatar_image(email)
    hash = Digest::MD5.hexdigest(email).to_s
    image_tag "http://www.gravatar.com/avatar/#{hash}?s=48"
  end
  
end
