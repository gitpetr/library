require 'rails_helper'

RSpec.describe V1::BookCopiesController, type: :controller do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:book_copy) { create(:book_copy) }
  let(:book) { create(:book) }

  before { request.env['HTTP_AUTHORIZATION'] = "Token token=#{api_key}" }

  describe '#index' do
    subject { get :index }

    context 'as admin' do
      let(:api_key) { admin.api_key }

      before { book_copy }

      it { is_expected.to be_successful }
      it 'returns valid JSON' do
        body = JSON.parse(subject.body)
        expect(body['book_copies'].length).to eq(1)
      end
    end

    context 'as user' do
      let(:api_key) { user.api_key }

      it { is_expected.to be_unauthorized }
    end
  end

  describe '#show' do
    subject { get :show, params: { id: book_copy.id } }

    context 'as admin' do
      let(:api_key) { admin.api_key }

      it { is_expected.to be_successful }

      it 'returns valid JSON' do
        subject
        expect(response.body).to eq({ book_copy: BookCopySerializer.new(book_copy).attributes }.to_json)
      end
    end

    context 'as user' do
      let(:api_key) { user.api_key }

      it { is_expected.to be_unauthorized }
    end
  end

  describe '#create' do
    let(:book_copy_params) { { isbn: '00001' } }

    subject { post :create, params: { book_copy: book_copy_params } }

    context 'as admin' do
      let(:api_key) { admin.api_key }

      context 'with valid params' do
        let(:book_copy_params) { { isbn: '00001', published: Date.today, book_id: book.id, format: 'hardback' } }

        it { is_expected.to be_created }

        it 'creates an book_copy' do
          expect { subject }.to change(BookCopy, :count).by(1)
        end
      end

      context 'with invalid params' do
        it { is_expected.to have_http_status(:unprocessable_entity) }
      end
    end

    context 'as user' do
      let(:api_key) { user.api_key }

      it { is_expected.to be_unauthorized }
    end
  end

  describe '#update' do
    let(:book_copy_params) { {} }

    subject { put :update, params: { id: book_copy.id, book_copy: book_copy_params } }

    context 'as admin' do
      let(:api_key) { admin.api_key }

      context 'with valid params' do
        let(:book_copy_params) { { isbn: '0000033' } }

        it 'updates requested record' do
          subject
          expect(book_copy.reload.isbn).to eq(book_copy_params[:isbn])
          expect(response.body).to eq({ book_copy: BookCopySerializer.new(book_copy.reload).attributes }.to_json)
        end

        it { is_expected.to be_successful }
      end

      context 'with invalid params' do
        let(:book_copy_params) { { isbn: nil } }

        it { is_expected.to have_http_status(:unprocessable_entity) }
      end
    end

    context 'as user' do
      let(:api_key) { user.api_key }

      it { is_expected.to be_unauthorized }
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { id: book_copy.id } }

    before { book_copy }

    context 'as admin' do
      let(:api_key) { admin.api_key }

      it 'removes requested record' do
        expect { subject }.to change(BookCopy, :count).by(-1)
      end

      it { is_expected.to be_no_content }
    end

    context 'as user' do
      let(:api_key) { user.api_key }

      it { is_expected.to be_unauthorized }
    end
  end

  describe '#borrow' do
    subject { put :borrow, params: book_copy_params }

    context 'as admin' do
      let(:api_key) { admin.api_key }

      context 'without user_id param' do
        let(:book_copy_params) { { id: book_copy.id } }

        it { is_expected.to have_http_status(:unprocessable_entity) }
      end

      context 'with user_id param' do
        let(:book_copy_params) { { id: book_copy.id, user_id: user.id } }

        context 'book is not borrowed' do
          it { is_expected.to be_successful }
        end

        context 'book is borrowed' do
          before { book_copy.update_column(:user_id, user.id) }

          it { is_expected.to have_http_status(:unprocessable_entity) }
        end
      end
    end

    context 'as user' do
      let(:api_key) { user.api_key }
      let(:book_copy_params) { { id: book_copy.id } }

      context 'book is not borrowed' do
        it { is_expected.to be_successful }
      end

      context 'book is borrowed' do
        before { book_copy.update_column(:user_id, admin.id) }

        it { is_expected.to have_http_status(:unprocessable_entity) }
      end
    end
  end

  describe '#return_book' do
    subject { put :return_book, params: book_copy_params }

    context 'as admin' do
      let(:api_key) { admin.api_key }

      context 'without user_id param' do
        let(:book_copy_params) { { id: book_copy.id } }

        it { is_expected.to have_http_status(:unprocessable_entity) }
      end

      context 'with user_id param' do
        let(:book_copy_params) { { id: book_copy.id, user_id: user.id } }

        context 'book is not borrowed' do
          it { is_expected.to have_http_status(:unprocessable_entity) }
        end

        context 'book is borrowed' do
          context 'user_id matches to a book_copy user_id' do
            before { book_copy.update_column(:user_id, user.id) }

            it { is_expected.to be_successful }
          end

          context 'user_id does not match to a book_copy user_id' do
            let(:another_user) { create(:user) }

            before { book_copy.update_column(:user_id, another_user.id) }

            it { is_expected.to be_successful }
          end
        end
      end
    end

    context 'as user' do
      let(:api_key) { user.api_key }
      let(:book_copy_params) { { id: book_copy.id } }

      context 'book is borrowed' do
        context 'current user is a user who borrowed a book' do
          before { book_copy.update_column(:user_id, user.id) }

          it { is_expected.to be_successful }
        end

        context 'current user is not a user who borrowed a book' do
          let(:another_user) { create(:user) }

          before { book_copy.update_column(:user_id, another_user.id) }

          it { is_expected.to be_forbidden }
        end
      end

      context 'book is not borrowed' do
        it { is_expected.to be_forbidden }
      end
    end
  end
end
