# Handles every web request about patients: list, show, create, edit, delete.
# Rails calls these methods "actions". Each one maps to a URL in config/routes.rb.
class PatientsController < ApplicationController
  before_action :set_patient, only: %i[ show edit update destroy ]

  # GET /patients
  # GET /patients?q=smith   (search by name)
  def index
    if params[:q].present?
      # VULN: SQL injection.
      # The search text from the URL is pasted straight into the SQL string.
      # A visitor can type   ' OR 1=1 --   and rewrite the query, or worse.
      # Safe version:  Patient.where("name LIKE ?", "%#{params[:q]}%")
      @patients = Patient.where("name LIKE '%#{params[:q]}%'")
    else
      @patients = Patient.all
    end
  end

  # GET /patients/1
  def show
  end

  # GET /patients/new
  def new
    @patient = Patient.new
  end

  # GET /patients/1/edit
  def edit
  end

  # POST /patients
  def create
    @patient = Patient.new(patient_params)

    if @patient.save
      redirect_to @patient, notice: "Patient was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /patients/1
  def update
    if @patient.update(patient_params)
      redirect_to @patient, notice: "Patient was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /patients/1
  def destroy
    @patient.destroy!
    redirect_to patients_url, notice: "Patient was successfully destroyed.", status: :see_other
  end

  private
    # Look up the patient named in the URL (/patients/:id) before show/edit/update/destroy.
    def set_patient
      @patient = Patient.find(params[:id])
    end

    # Decide which form fields a browser is allowed to set on a Patient.
    def patient_params
      # VULN: mass assignment.
      # permit! accepts EVERY field the browser sends. A user could add
      # discount_tier=platinum to the form and grant themselves a discount.
      # Safe version:  .permit(:name, :date_of_birth, :email, :insurance_id)
      params.require(:patient).permit!
    end
end
