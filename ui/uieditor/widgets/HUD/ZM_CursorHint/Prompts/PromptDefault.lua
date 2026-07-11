-- Default Prompt Widget - Shows for any hint we don't customize
CoD.PromptDefault = InheritFrom( LUI.UIElement )

function CoD.PromptDefault.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptDefault )
	self.id = "PromptDefault"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- Start hidden
	
	-- image_3a5dcba7b0d44850
	self.bgMain = LUI.UIImage.new()
	self.bgMain:setLeftRight(true, false, 616, 772)
	self.bgMain:setTopBottom(true, false, 447, 518)
	self.bgMain:setImage(RegisterImage("i_mtl_image_3a5dcba7b0d44850"))
	self.bgMain:setRGB(1, 1, 1)
	self:addElement(self.bgMain)
	
	-- image_6bac5ab6cef2cf7d
	self.bgFrame = LUI.UIImage.new()
	self.bgFrame:setLeftRight(true, false, 618, 775)
	self.bgFrame:setTopBottom(true, false, 449, 517)
	self.bgFrame:setImage(RegisterImage("i_mtl_image_6bac5ab6cef2cf7d"))
	self.bgFrame:setRGB(1, 1, 1)
	self:addElement(self.bgFrame)
	
	-- image_7d9423641070f37e
	self.bgIcon = LUI.UIImage.new()
	self.bgIcon:setLeftRight(true, false, 546, 615)
	self.bgIcon:setTopBottom(true, false, 445, 518)
	self.bgIcon:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
	self.bgIcon:setRGB(1, 1, 1)
	self:addElement(self.bgIcon)
	
	-- Description (hint text - dynamically set)
	self.hintText = LUI.UIText.new()
	self.hintText:setLeftRight(true, false, 620, 766)
	self.hintText:setTopBottom(true, false, 467, 474)
	self.hintText:setText(Engine.Localize("Hint text here"))
	self.hintText:setTTF("fonts/ltromatic.ttf")
	self.hintText:setRGB(1, 1, 1)
	self.hintText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.hintText)
	
	-- image_8a21f7a0f930d3f
	self.bgBorder = LUI.UIImage.new()
	self.bgBorder:setLeftRight(true, false, 544, 775)
	self.bgBorder:setTopBottom(true, false, 444, 520)
	self.bgBorder:setImage(RegisterImage("i_mtl_image_8a21f7a0f930d3f"))
	self.bgBorder:setRGB(1, 1, 1)
	self:addElement(self.bgBorder)
	
	-- i_mtl_ui_icon_zm_ping_documents
	self.defaultIcon = LUI.UIImage.new()
	self.defaultIcon:setLeftRight(true, false, 556, 607)
	self.defaultIcon:setTopBottom(true, false, 457, 506)
	self.defaultIcon:setImage(RegisterImage("i_mtl_ui_icon_zm_ping_documents"))
	self.defaultIcon:setRGB(1, 1, 1)
	self:addElement(self.defaultIcon)
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end
