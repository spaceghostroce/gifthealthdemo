class PrescriptionsController < ApplicationController
  # VULN: CSRF protection turned off.
  # Rails normally requires a hidden token on every form submit so another
  # website cannot trick a logged-in browser into posting here. This line
  # removes that check for the whole controller.
  skip_forgery_protection

  before_action :set_prescription, only: %i[ show edit update destroy ]

  # GET /prescriptions
  def index
    @prescriptions = Prescription.all
  end

  # GET /prescriptions/1
  def show
  end

  # GET /prescriptions/new
  def new
    @prescription = Prescription.new
  end

  # GET /prescriptions/1/edit
  def edit
  end

  # POST /prescriptions
  def create
    @prescription = Prescription.new(prescription_params)

    if @prescription.save
      redirect_to @prescription, notice: "Prescription was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /prescriptions/1
  def update
    if @prescription.update(prescription_params)
      redirect_to @prescription, notice: "Prescription was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /prescriptions/1
  def destroy
    @prescription.destroy!
    redirect_to prescriptions_url, notice: "Prescription was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_prescription
      @prescription = Prescription.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def prescription_params
      params.require(:prescription).permit(:patient_id, :drug_name, :dosage, :notes)
    end
end
