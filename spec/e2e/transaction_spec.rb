describe 'ActiveGraph::Transaction' do
  context 'reading has_one relationships for ActiveGraph::Server' do
    before do
      stub_node_class('Clazz') do
        property :name
        has_one :out, :thing, type: nil, model_class: self
      end
    end

    before { Clazz }

    it 'returns a wrapped node inside and outside of transaction' do
      a = nil
      b = nil
      ActiveGraph::Base.transaction do
        a = Clazz.create name: 'a'
        b = Clazz.create name: 'b'
        a.thing = b
        expect(a.thing).to eq b
      end
      expect(a.thing).to eq(b)
    end
  end
end
