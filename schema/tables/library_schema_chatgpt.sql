-- ChatGPT Generated Library Schema
-- 拡張
due_at TIMESTAMPTZ NOT NULL,
checked_out_at TIMESTAMPTZ NOT NULL DEFAULT now(),
returned_at TIMESTAMPTZ,
return_branch_id UUID REFERENCES branch(branch_id),
return_by UUID REFERENCES staff(staff_id),
renew_count SMALLINT NOT NULL DEFAULT 0,
CONSTRAINT one_open_loan_per_item CHECK (
(returned_at IS NULL AND renew_count >= 0) OR (returned_at IS NOT NULL)
)
);


CREATE INDEX idx_loan_open ON loan(item_id) WHERE returned_at IS NULL;
CREATE INDEX idx_loan_patron_open ON loan(patron_id) WHERE returned_at IS NULL;


-- 予約（順番待ち）
CREATE TABLE reservation (
reservation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
item_id UUID REFERENCES item(item_id) ON DELETE CASCADE,
edition_id UUID REFERENCES edition(edition_id) ON DELETE CASCADE,
-- item 指定が優先されるが、未指定で版全体への予約も許可
patron_id UUID NOT NULL REFERENCES patron(patron_id) ON DELETE CASCADE,
pickup_branch_id UUID NOT NULL REFERENCES branch(branch_id),
requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
status TEXT NOT NULL CHECK (status IN ('queued','ready','picked_up','cancelled','expired')),
ready_at TIMESTAMPTZ,
expires_at TIMESTAMPTZ,
UNIQUE (patron_id, COALESCE(item_id, edition_id))
);


-- 延滞金と支払い
CREATE TABLE fine (
fine_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
patron_id UUID NOT NULL REFERENCES patron(patron_id) ON DELETE CASCADE,
loan_id UUID REFERENCES loan(loan_id) ON DELETE SET NULL,
amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
reason TEXT NOT NULL,
assessed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
is_paid BOOLEAN NOT NULL DEFAULT FALSE
);


CREATE TABLE payment (
payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
patron_id UUID NOT NULL REFERENCES patron(patron_id) ON DELETE CASCADE,
fine_id UUID REFERENCES fine(fine_id) ON DELETE SET NULL,
amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
method TEXT CHECK (method IN ('cash','card','online')),
received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
received_by UUID REFERENCES staff(staff_id)
);


-- 監査ログ（重要操作）
CREATE TABLE audit_log (
audit_id BIGSERIAL PRIMARY KEY,
occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
actor_staff_id UUID REFERENCES staff(staff_id),
actor_patron_id UUID REFERENCES patron(patron_id),
action TEXT NOT NULL, -- e.g. CHECKOUT, RETURN, WRITE_OFF
entity TEXT NOT NULL, -- e.g. item, loan, fine
entity_id UUID,
payload JSONB
);


-- よく使う検索のためのインデックス
CREATE INDEX idx_item_status ON item(status);
CREATE INDEX idx_item_barcode ON item(barcode);
CREATE INDEX idx_edition_isbn ON edition(isbn13);
CREATE INDEX idx_work_title_trgm ON work USING GIN (title gin_trgm_ops);