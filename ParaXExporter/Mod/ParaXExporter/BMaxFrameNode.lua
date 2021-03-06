NPL.load("(gl)script/ide/math/vector.lua");
NPL.load("(gl)Mod/ParaXExporter/BlockConfig.lua");
NPL.load("(gl)Mod/ParaXExporter/BlockDirection.lua");
NPL.load("(gl)Mod/ParaXExporter/Model/ModelBone.lua");
NPL.load("(gl)Mod/ParaXExporter/Common.lua");

local BlockConfig = commonlib.gettable("Mod.ParaXExporter.BlockConfig");
local BlockDirection = commonlib.gettable("Mod.ParaXExporter.BlockDirection");

local BMaxFrameNode = commonlib.inherit(commonlib.gettable("Mod.ParaXExporter.BMaxNode"), commonlib.gettable("Mod.ParaXExporter.BMaxFrameNode"));
local vector3d = commonlib.gettable("mathlib.vector3d");
local ModelBone = commonlib.gettable("Mod.ParaXExporter.Model.ModelBone");
local Common = commonlib.gettable("Mod.ParaXExporter.Common")

function BMaxFrameNode:ctor()
	self.m_nParentIndex = -1;
end

function BMaxFrameNode:init(model, x, y, z, template_id, block_data, bone_index)
	self.model = model;
	self.x = x;
	self.y = y;
	self.z = z;
	self.template_id = template_id;
	self.block_data = block_data;
	self.bone_index = bone_index;
	self.bone = ModelBone:new();
	self.bone_name = nil;
	self.m_children = {};


	return self;
end
	
function BMaxFrameNode:GetBone()
	return self.bone;
end


function BMaxFrameNode:UpdatePivot(m_fScale)
	local x, y, z = self.model.m_centerPos[1] + BlockConfig.g_blockSize * 0.5, self.y + BlockConfig.g_blockSize * 0.5, self.z - self.model.m_centerPos[3] + BlockConfig.g_blockSize * 0.5;
	local pivot =  vector3d:new({x,y,z});
	--pivot = pivot * 3;
	self.bone.bUsePivot = true;
	self.bone.pivot = pivot:MulByFloat(m_fScale);
	self.bone.flags = 0;
end

function BMaxFrameNode:GetParent()
	if (m_nParentIndex >= 0) then
		local pParent = self.m_nodes[m_nParentIndex];
		if pParent ~= nil then
			return pParent;
		end
	end
	return nil;
end

function BMaxFrameNode:AutoSetBoneName()
	if self.bone_name == nil then
		local bone_name = "bone";
		local pChild = self;
		local nSide = -1;
		local nMultiChildParentCount = 0;
		local nParentCount = 0;

		while pChild do
			local pParent = pChild:GetParent();
			if (pParent and #pParent.m_children > 1) then
				if pParent.z > pChild.z then
					nSide = 1;
				elseif pParent.z < pChild.z then
					nSide = 0;
				end
			end
			pChild = pParent;
			nParentCount = nParentCount + 1;
		end
		
		if nParentCount > 0 then
			nParentCount = nParentCount - 1;
		end

		if nSide == 0 then
			bone_name = bone_name.."_left";
		elseif nSide == 1 then
			bone_name =  bone_name.."_right";
		end

		if nSide >= 0 and nMultiChildParentCount > 1 then
			bone_name =  bone_name.."_mp"..nMultiChildParentCount;
		end

		bone_name = bone_name.."_p"..nParentCount;

		local parent = self:GetParent();
		if parent and #parent.m_children == 1 then
			parent = parent:GetParent();

			if parent and #parent.m_children == 1 then
				parent = parent:GetParent();
		
				if parent and #parent.m_children > 1 then
					parent = parent:GetParent();
					bone_name = bone_name.."_IK";		
				end	
			end
		end
		self.bone_name = bone_name;
	end
end

function BMaxFrameNode:GetParentBone(bRefresh)
	if bRefresh then

		self:SetParentIndex(-1);

		local cx = self.x;
		local cy = self.y;
		local cz = self.z;

		local side = BlockDirection:GetBlockSide(self.block_data);
		local offset = BlockDirection:GetOffsetBySide(side);

		local dx = offset.x;
		local dy = offset.y;
		local dz = offset.z;
		local maxBoneLength = self.model.MaxBoneLengthHorizontal;
		if dy ~= 0 then
			maxBoneLength = self.model.MaxBoneLengthVertical;
		end

		for i = 1, maxBoneLength do
			local x = cx + dx * i;
			local y = cy + dy * i;
			local z = cz + dz * i;

			local parent = self.model:GetFrameNode(x, y, z);
			if (parent) then
				
				local parentSide = BlockDirection:GetBlockSide(parent.block_data);
				local opSide = BlockDirection:GetOpSide(parentSide);
				if opSide ~= side or (dx + dy + dz) < 0 then
					if not self:IsAncestorOf(parent_node) then
						self:SetParentIndex(parent:GetIndex());
					end
				end
			end
		end
	end
end



function BMaxFrameNode:SetParentIndex(index)
	self.m_nParentIndex = index;

	local parent = self:GetParent();
	if (parent) then
		parent:AddChild(self);
		self.bone.parent = parent.bone_index;
	end
end

function BMaxFrameNode:AddChild(child)
	local nIndex = child:GetIndex();
	for k, childIndex in ipairs(self.m_children) do
		if (childIndex == nIndex) then
			return;
		end
	end
	table.insert(self.m_children, nIndex);
end

function BMaxFrameNode:GetParent()
	if (self.m_nParentIndex >= 0)then
		
		local parent = self.model.m_nodes[self.m_nParentIndex];
		if (parent) then
			return parent;
		end
	end
	return nil;
end

function BMaxFrameNode:IsAncestorOf(pChild)
	while (pChild) do
		if (pChild == this) then
			return true;
		elseif (pChild:HasParent()) then
			return false;
		else
			pChild = pChild:GetParent();
		end
	end
    return false;
end

function BMaxFrameNode:HasParent()
	return m_nParentIndex >= 0;
end

function BMaxFrameNode:AddBoneAnimation(time, data, range, anim)

	local block = nil;
	if anim == "rot" then
		block = self.bone.rotation;	
	elseif anim == "trans" then
		block = self.bone.translation
	elseif anim == "scale" then
		block = self.bone.scaling;
	end

	if block then
		for k , v in ipairs(data) do
			if time[k] and data[k] then
				self.bone:AddAnimationFrame(block, time[k], data[k]);
			end
		end
	end
	
	self.bone:AddAnimationRange(block, range);
end

function BMaxFrameNode:ToBoneNode()
	return self;
end