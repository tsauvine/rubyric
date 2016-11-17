require "rails_helper"

describe Review, '.cast_grade' do
  it 'returns integer' do
    expect(Review.cast_grade('2')).to eq 2
    expect(Review.cast_grade('0')).to eq 0
    expect(Review.cast_grade('-56')).to eq -56
    expect(Review.cast_grade('1e2')).to eq 100
  end
  
  it 'returns float' do
    expect(Review.cast_grade('34.0')).to eq 34.0
    expect(Review.cast_grade('0.0')).to eq 0.0
    expect(Review.cast_grade('-4.6')).to eq -4.6
    expect(Review.cast_grade('3.78e2')).to eq 378.0
  end
  
  it 'returns string' do
    expect(Review.cast_grade('fail')).to eq 'fail'
    expect(Review.cast_grade('')).to eq ''
  end
end

describe Review, '#compare_grades' do
  it 'considers nil smaller than anything' do
    expect(Review.compare_grades(nil,   '-4')).to eq -1
    expect(Review.compare_grades(nil,    '0')).to eq -1
    expect(Review.compare_grades(nil,    '5')).to eq -1
    expect(Review.compare_grades(nil, '75.8')).to eq -1
    expect(Review.compare_grades(nil, 'fail')).to eq -1
    expect(Review.compare_grades(nil,     '')).to eq -1
    expect(Review.compare_grades('-4'  , nil)).to eq 1
    expect(Review.compare_grades('0'   , nil)).to eq 1
    expect(Review.compare_grades('5'   , nil)).to eq 1
    expect(Review.compare_grades('75.8', nil)).to eq 1
    expect(Review.compare_grades('fail', nil)).to eq 1
    expect(Review.compare_grades(''    , nil)).to eq 1
  end
  
  it 'considers numerical grades smaller than textual grades' do
    expect(Review.compare_grades('-2',    'A')).to eq -1
    expect(Review.compare_grades( '0', 'fail')).to eq -1
    expect(Review.compare_grades('45', 'good')).to eq -1
    expect(Review.compare_grades( '0',     '')).to eq -1
    
    expect(Review.compare_grades(   'A', '-2')).to eq 1
    expect(Review.compare_grades('fail',  '0')).to eq 1
    expect(Review.compare_grades('good', '45')).to eq 1
    expect(Review.compare_grades(    '',  '0')).to eq 1
  end
  
  it 'compares numbers correctly' do
    expect(Review.compare_grades( '2',  '11')).to eq -1
    expect(Review.compare_grades( '5',  '-5')).to eq 1
    expect(Review.compare_grades( '34',  '34')).to eq 0
    expect(Review.compare_grades( '4.7',  '5')).to eq -1
  end
  
  it 'compares textual grades correctly' do
    expect(Review.compare_grades('A',  'B')).to eq -1
    expect(Review.compare_grades('banana', 'auto')).to eq 1
  end
  
  it 'considers two nils equal' do
    expect(Review.compare_grades(nil, nil)).to eq 0
  end
  
  it 'considers equal strings equal' do
    expect(Review.compare_grades('', '')).to eq 0
    expect(Review.compare_grades('fail', 'fail')).to eq 0
  end
  
  it 'considers equal numbers equal' do
    expect(Review.compare_grades('2', '2.0')).to eq 0
    expect(Review.compare_grades('02', '2')).to eq 0
    expect(Review.compare_grades('-45', '-45')).to eq 0
  end
end

describe Review, '#compare_grades!' do
  it 'refuses to compare strings' do
    expect(Review.compare_grades!(nil,   'B')).to eq nil
    expect(Review.compare_grades!('4.6', 'A')).to eq nil
    expect(Review.compare_grades!('B',   nil)).to eq nil
    expect(Review.compare_grades!('A',   '7')).to eq nil
    expect(Review.compare_grades!('A',   'B')).to eq nil
  end
  
   it 'considers nils smaller than numbers' do
    expect(Review.compare_grades(nil,   '-4')).to eq -1
    expect(Review.compare_grades(nil,    '0')).to eq -1
    expect(Review.compare_grades(nil,    '5')).to eq -1
    expect(Review.compare_grades(nil, '75.8')).to eq -1
    expect(Review.compare_grades('-4'  , nil)).to eq 1
    expect(Review.compare_grades(0     , nil)).to eq 1
    expect(Review.compare_grades('5'   , nil)).to eq 1
    expect(Review.compare_grades('75.8', nil)).to eq 1
  end
  
   it 'compares numbers correctly' do
    expect(Review.compare_grades( '2',  '11')).to eq -1
    expect(Review.compare_grades( '5',  '-5')).to eq 1
    expect(Review.compare_grades( '34',  '34')).to eq 0
    expect(Review.compare_grades( '4.7',  '5')).to eq -1
    expect(Review.compare_grades('2', '2.0')).to eq 0
    expect(Review.compare_grades('02', '2')).to eq 0
    expect(Review.compare_grades('-45', '-45')).to eq 0
  end
end
