-- ��ת���ͻ����޸�ԭ����
-- �����ת���ͣ���ԭ���Ͳ��䣬�����õ�ԭ���͵ĵط����滻�������ͣ�
-- �������й����е�һ����������û�д�״̬�����֮�����õ�ԭ����(����ת��
-- ĳ�����ͣ��������ְ���ԭ����)���������滻���ɾ�
-- ������޸����ͣ��������õ������͵ĵط����ó�����ע������͵ñ仯���Ա㴫����ʵ�ֵ
-- ���ϣ��޸������ƺ�������
local meta = {
	{
		type = "BlockCfg",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.name = "hello, hello"
			ret.pos = ctor("Vector4", oval.pos)

			return ret
		end
	},
}

for _, patch in ipairs(meta) do
	patch.value = string.dump(patch.value)
end

return {
	meta = meta
}
