# Sample data. Load with:  bin/rails db:seed
# All patients are fictional.

alice = Patient.create!(name: "Alice Rivera", date_of_birth: "1984-03-12",
                        email: "alice@example.com", insurance_id: "INS-10001",
                        discount_tier: "standard")
bob   = Patient.create!(name: "Bob Okafor", date_of_birth: "1971-11-02",
                        email: "bob@example.com", insurance_id: "INS-10002",
                        discount_tier: "standard")

Prescription.create!(patient: alice, drug_name: "Metformin", dosage: "500 mg twice daily",
                     notes: "Take with food.")
Prescription.create!(patient: bob, drug_name: "Lisinopril", dosage: "10 mg daily",
                     notes: "<b>Monitor blood pressure weekly.</b>")
